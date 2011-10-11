# require "async-rack"

module Rack
  module Escrow
    class Middleware
      REQUEST_METHOD = 'REQUEST_METHOD'
      REQUEST_PATH   = 'REQUEST_PATH'
      POST           = 'POST'
      RAILS_ROUTES   = 'action_dispatch.routes'
      
      def initialize app, rails_application
        puts "Initializing EscrowMiddleware"
        @rails_application = rails_application
        rails_application.config.escrow = self
        @app = app
        @recognized_escrow_segments = []
      end

      def call env
        status, header, response = @app.call env
        [ status, header, response ]

        if is_escrowed? env
          # Redirect to /escrows/work
          status = 303 # See Other
          response = [ 'Escrowed' ]
        end

        [ status, header, response ]
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

