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
    EXPIRE_COOKIE    = Time.gm(1979, 1, 1)
    RAILS_ROUTES     = 'action_dispatch.routes'
    LOCATION         = 'Location'
    CONTENT_TYPE     = 'Content-Type'
    JSON_CONTENT     = /^application\/json/
    ESCROW_MATCH     = /^(.+)\.(.+)$/
    TTL              = 180 # Seconds until proxied response expires
    NONCE            = 'nonce'
    RESPONSE         = 'response'
    BAD_NONCE        = 'Bad nonce'
    DATA_KEY         = 'secure_escrow'
    REDIRECT_CODES   = 300..399
    HTTPS            = 'HTTPS'
    ON               = 'on'
  end

  class Middleware
    def initialize next_app, rails_app, config
      @next_app   = next_app
      @rails_app  = rails_app
      @config     = config
      @store      = config[:store]
    end

    def call env
      handle_presenter presenter(env)
    end

    def presenter env
      Presenter.new @next_app, @rails_app, @config, env
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

      attr_reader :next_app, :rails_app, :store, :config, :env

      def initialize next_app, rails_app, config, env
        @next_app   = next_app
        @rails_app  = rails_app
        @config     = config
        @store      = config[:store]
        @env        = env
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
        return false unless POST == env[REQUEST_METHOD] && ON == env[HTTPS]
        recognized = recognize_path
        config[:allow_non_escrow_routes] ?
          recognized :
          recognized && recognized[:escrow]
      end

      def serve_response_from_escrow!
        key = escrow_key escrow_id
        value = JSON.parse(store.get key)

        if escrow_nonce == value[NONCE]
          # Destroy the stored value
          store.del key

          status, headers, body = value[RESPONSE]

          if headers[CONTENT_TYPE] && JSON_CONTENT.match(headers[CONTENT_TYPE])
            body = [
              "<html><body><script id=\"response\" type=\"text/x-escrow-json\">%s</script></body></html>" %
              { status: status, body: body.join.to_s }.to_json
            ]
            headers[CONTENT_TYPE] = "text/html; charset=utf-8"
            status = 200
          end

          expire_cookie_token!(headers)

          [ status, headers, body ]
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

        store.setex key, TTL, value.to_json

        [ id, nonce ]
      end

      def generate_id_and_nonce
        [ UUID.generate, SecureRandom.hex(4) ]
      end

      def call_result
        @call_result ||= next_app.call env
      end

      def redirect_to_location token = nil
        redirect_to_options = {
          protocol: rails_config[:insecure_domain_protocol] || request.protocol,
          host:     rails_config[:insecure_domain_name]     || request.host,
          port:     rails_config[:insecure_domain_port]     || request.port,
        }

        if token && !homogenous_host_names?
          redirect_to_options.merge!(DATA_KEY => token)
        end

        routes.url_for(
          recognize_path.merge(redirect_to_options))
      end

      private
      def rails_config
        @rails_config ||= rails_app.config.secure_escrow
      end

      def set_cookie_token! headers, token
        Rack::Utils.set_cookie_header! headers, DATA_KEY,
          value: token,
          httponly: true
      end

      def expire_cookie_token! headers
        Rack::Utils.set_cookie_header! headers, DATA_KEY,
          value: "",
          httponly: true,
          expires: EXPIRE_COOKIE
      end

      def rewrite_location_header! header
        return unless header[LOCATION]

        # Rewrite redirect to secure domain
        header[LOCATION] = routes.url_for(
          routes.recognize_path(header[LOCATION]).merge(
            host:     rails_config[:insecure_domain_name],
            protocol: rails_config[:insecure_domain_protocol],
            port:     rails_config[:insecure_domain_port],
          ))

        header
      end

      def routes
        @routes ||= rails_app.routes
      end

      # TODO: Examine the performance implications of parsing the
      # Cookie / Query payload this early in the stack
      def escrow_id_and_nonce
        data = Array((homogenous_host_names? ?
          Rack::Utils.parse_query(env[HTTP_COOKIE], COOKIE_SEPARATOR) :
          Rack::Utils.parse_query(env[QUERY_STRING]))[DATA_KEY]).find do |e|
          e.match ESCROW_MATCH
        end

        return unless data
        match = data.match ESCROW_MATCH
        return unless match

        match[1..2]
      end

      def homogenous_host_names?
        rails_config[:secure_domain_name] == rails_config[:insecure_domain_name]
      end

      def recognize_path
        begin
          routes.recognize_path(
            env[REQUEST_PATH],
            method: env[REQUEST_METHOD]
          )
        rescue ActionController::RoutingError
        end
      end

    end

  end

end

