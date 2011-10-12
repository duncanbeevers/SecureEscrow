require "uuid"
# require "async-rack"

module Rack
  module Escrow
    class Middleware
      REQUEST_METHOD = 'REQUEST_METHOD'
      REQUEST_PATH   = 'REQUEST_PATH'
      POST           = 'POST'
      RAILS_ROUTES   = 'action_dispatch.routes'
      LOCATION       = 'Location'
      
      def initialize app, rails_application, store
        puts "Initializing EscrowMiddleware"
        @rails_application = rails_application
        rails_application.config.escrow = self
        @app   = app
        @store = store
        @recognized_escrow_segments = []
      end

      def call env
        status, header, response = @app.call env
        [ status, header, response ]

        if is_escrowed? env
          nonce = UUID.generate

          response_body = []
          response.each { |content| response_body.push(content) }

          resolved_store = @store.call
          key = "escrow:#{nonce}"
          resolved_store.set key, [ status, header, response_body.join() ].to_json

          # Set TTL on secure response
          resolved_store.expire key, 60

          # HTTP Status Code 303 - See Other
          redirect_to = "/escrow/#{nonce}"
          [ 303, header.merge(LOCATION => redirect_to), [ "Escrowed at #{nonce}" ] ]
        else
          [ status, header, response ]
        end
      end

      def recognize_escrow segment
        puts "Adding #{segment} to recognized escrow segments"
        @recognized_escrow_segments.push segment
      end
      private

      def rails_routes env
        @rails_routes ||= env[RAILS_ROUTES]
      end

      def is_escrowed? env
        method = env[REQUEST_METHOD]

        return false unless POST == method
        h = rails_routes(env).recognize_path env[REQUEST_PATH], method: method
        h[:escrow]
      end
    end
  end
end

