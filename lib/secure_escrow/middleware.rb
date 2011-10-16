require "uuid"

module SecureEscrow
  class Middleware
    REQUEST_METHOD = 'REQUEST_METHOD'
    REQUEST_PATH   = 'REQUEST_PATH'
    QUERY_STRING   = 'QUERY_STRING'
    POST           = 'POST'
    GET            = 'GET'
    RAILS_ROUTES   = 'action_dispatch.routes'
    LOCATION       = 'Location'
    ESCROW_MATCH   = /^escrow=(.+)\.(.+)$/
    TTL            = 180 # Seconds until proxied response expires
    NONCE          = 'nonce'
    RESPONSE       = 'response'
    BAD_NONCE      = 'Bad nonce'

    attr_reader :store

    def initialize app, store
      @app = app
      @store = store
    end

    def call env
      if serve_from_escrow? env
        # No need to call the Rails app if we're serving a response from escrow
        return response_from_escrow env
      else
        status, header, response = @app.call env

        if keep_in_escrow? env
          id, nonce = store_in_escrow status, header, response
          token = "#{id}.#{nonce}"

          # HTTP Status Code 303 - See Other
          routes = @app.routes
          config = @app.config

          redirect_to = routes.url_for(
            routes.recognize_path(env['REQUEST_PATH'], env).merge(
                protocol: config.insecure_domain_protocol,
                host:     config.insecure_domain_name,
                port:     config.insecure_domain_port,
                escrow:   token
              ))

          return [ 303, { LOCATION => redirect_to }, [ "Escrowed at #{token}" ] ]
        else
          return [ status, header, response ]
        end
      end
    end

    private
    def rails_routes env
      @rails_routes ||= env[RAILS_ROUTES]
    end

    def keep_in_escrow? env
      method = env[REQUEST_METHOD]

      return false unless POST == method
      h = rails_routes(env).recognize_path env[REQUEST_PATH], method: method
      h[:escrow]
    end

    # Take a Rack status, header, and response
    # Serialize the response to a string
    # Serialize the structure as JSON
    # Generate a unique id for the data
    # Generate a nonce for the data
    # Store in Redis
    def store_in_escrow status, header, response
      id = UUID.generate
      nonce = SecureRandom.hex(4)

      response_body = []
      response.each { |content| response_body.push(content) }
      response.close if response.respond_to? :close

      config = @app.config
      routes = @app.routes

      # Rewrite redirect to secure domain
      header[LOCATION] = routes.url_for(
        routes.recognize_path(header[LOCATION]).merge(
          host:     config.insecure_domain_name,
          protocol: config.insecure_domain_protocol,
          port:     config.insecure_domain_port
        ))

      value = {
        NONCE    => nonce,
        RESPONSE => [ status, header, [ response_body.join ] ]
      }

      # Serialze the nonce and Rack response triplet
      # and store in Redis
      key = escrow_key id
      store.set key, value.to_json

      # Set TTL on secure response
      store.expire key, TTL

      [ id, nonce ]
    end

    def serve_from_escrow? env
      return false unless GET == env[REQUEST_METHOD]
      id, nonce = escrow_id_and_nonce env
      key = escrow_key id
      store.exists key
    end

    def response_from_escrow env
      id, nonce = escrow_id_and_nonce env
      key = escrow_key id
      value = JSON.parse(store.get key)

      if nonce == value[NONCE]
        # Destroy the stored value
        store.del key

        return value[RESPONSE]
      else
        # HTTP Status Code 403 - Forbidden
        return [ 403, {}, [ BAD_NONCE ] ]
      end
    end

    def escrow_key id
      "escrow:#{id}"
    end

    def escrow_id_and_nonce env
      match = env[QUERY_STRING].match ESCROW_MATCH
      match && match[1..2]
    end
  end
end

