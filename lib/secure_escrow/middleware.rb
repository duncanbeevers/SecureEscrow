require "uuid"

module SecureEscrow
  module MiddlewareConstants
    REQUEST_METHOD   = 'REQUEST_METHOD'
    HTTP_COOKIE      = 'HTTP_COOKIE'
    REQUEST_PATH     = 'REQUEST_PATH'
    QUERY_STRING     = 'QUERY_STRING'
    POST             = 'POST'
    GET              = 'GET'
    COOKIE_SEPARATOR = ';'
    RAILS_ROUTES     = 'action_dispatch.routes'
    LOCATION         = 'Location'
    CONTENT_TYPE     = 'Content-Type'
    ESCROW_MATCH     = /^(.+)\.(.+)$/
    TTL              = 180 # Seconds until proxied response expires
    NONCE            = 'nonce'
    RESPONSE         = 'response'
    BAD_NONCE        = 'Bad nonce'
    DATA_KEY         = 'secure_escrow'
    REDIRECT_CODES   = 300..399
  end

  class Middleware
    def initialize app, store
      @app = app
      @store = store
    end

    def call env
      handle_presenter presenter(env)
    end

    def presenter env
      Presenter.new @app, @store, env
    end

    def handle_presenter e
      if e.serve_response_from_escrow?
        e.serve_response_from_escrow!
      elsif e.response_is_redirect?
        e.redirect_to_response!
      elsif e.store_response_in_escrow?
        e.store_response_in_escrow_and_redirect!
      else
        e.serve_response_from_application!
      end
    end

    class Presenter
      include MiddlewareConstants

      attr_reader :app, :store, :env

      def initialize app, store, env
        @app   = app
        @store = store
        @env   = env
      end

      def serve_response_from_escrow?
        return false unless GET == env[REQUEST_METHOD]
        return false unless escrow_id

        store.exists escrow_key(escrow_id)
      end

      def response_is_redirect?
        status, header, response = call_result
        REDIRECT_CODES.include? status
      end

      def store_response_in_escrow?
        method = env[REQUEST_METHOD]
        return false unless POST == method
        recognize_path[:escrow]
      end

      def serve_response_from_escrow!
        key = escrow_key escrow_id
        value = JSON.parse(store.get key)

        if escrow_nonce == value[NONCE]
          # Destroy the stored value
          store.del key

          return value[RESPONSE]
        else
          # HTTP Status Code 403 - Forbidden
          return [ 403, {}, [ BAD_NONCE ] ]
        end
      end

      def redirect_to_response!
        status, header, response = call_result
        rewrite_location_header! header
        [ status, header, response ]
      end

      def store_response_in_escrow_and_redirect!
        status, header, response = call_result
        id, nonce = store_in_escrow status, header, response
        token = "#{id}.#{nonce}"

        response_headers = {
          LOCATION      => redirect_to_location(token),
          CONTENT_TYPE  => header[CONTENT_TYPE]
        }
        set_cookie_token!(response_headers, token) if homogenous_host_names?

        # HTTP Status Code 303 - See Other
        return [ 303, response_headers, [ "Escrowed at #{token}" ] ]
      end

      def serve_response_from_application!
        call_result
      end

      def escrow_id
        @escrow_id ||= (escrow_id_and_nonce || [])[0]
      end

      def escrow_nonce
        @escrow_nonce ||= (escrow_id_and_nonce || [])[1]
      end

      def escrow_key id
        "escrow:#{id}"
      end

      # Take a Rack status, header, and response
      # Serialize the response to a string
      # Serialize the structure as JSON
      # Generate a unique id for the data
      # Generate a nonce for the data
      # Store in Redis
      def store_in_escrow status, header, response
        id, nonce = generate_id_and_nonce

        response_body = []
        response.each { |content| response_body.push(content) }
        response.close if response.respond_to? :close

        rewrite_location_header! header

        value = {
          NONCE    => nonce,
          RESPONSE => [ status, header, [ response_body.join ] ]
        }

        # Serialze the nonce and Rack response triplet,
        # store in Redis, and set TTL
        key = escrow_key id
        store.setex key, value.to_json, TTL

        [ id, nonce ]
      end

      def generate_id_and_nonce
        [ UUID.generate, SecureRandom.hex(4) ]
      end

      def call_result
        @call_result ||= app.call env
      end

      def redirect_to_location token = nil
        routes = app.routes
        config = app.config

        redirect_to_options = {
          protocol: config.insecure_domain_protocol,
          host:     config.insecure_domain_name,
          port:     config.insecure_domain_port
        }

        if token && !homogenous_host_names?
          redirect_to_options.merge!(DATA_KEY => token)
        end

        routes.url_for(
          recognize_path.merge(redirect_to_options))
      end

      private
      def set_cookie_token! headers, token
        Rack::Utils.set_cookie_header!(headers, DATA_KEY,
          value: token,
          httponly: true)
      end

      def rewrite_location_header! header
        return unless header[LOCATION]

        config = app.config
        routes = app.routes

        # Rewrite redirect to secure domain
        header[LOCATION] = routes.url_for(
          routes.recognize_path(header[LOCATION]).merge(
            host:     config.insecure_domain_name,
            protocol: config.insecure_domain_protocol,
            port:     config.insecure_domain_port
          ))

        header
      end

      def rails_routes
        @rails_routes ||= app.routes
      end

      # TODO: Examine the performance implications of parsing the
      # Cookie / Query payload this early in the stack
      def escrow_id_and_nonce
        data = (homogenous_host_names? ?
          Rack::Utils.parse_query(env[HTTP_COOKIE], COOKIE_SEPARATOR) :
          Rack::Utils.parse_query(env[QUERY_STRING]))[DATA_KEY]

        return unless data
        match = data.match ESCROW_MATCH
        return unless match

        match[1..2]
      end

      def homogenous_host_names?
        config = app.config
        config.secure_domain_name == config.insecure_domain_name
      end

      def recognize_path
        begin
          rails_routes.recognize_path(
            env[REQUEST_PATH],
            method: env[REQUEST_METHOD]
          )
        rescue ActionController::RoutingError
          {}
        end
      end

    end

  end

end

