require "uuid"
require "active_support"

module Rack
  module Escrow
    class Middleware
      REQUEST_METHOD = 'REQUEST_METHOD'
      REQUEST_PATH   = 'REQUEST_PATH'
      POST           = 'POST'
      GET            = 'GET'
      RAILS_ROUTES   = 'action_dispatch.routes'
      LOCATION       = 'Location'
      ESCROW_MATCH   = /^\/escrow\/(.+)\/(.+$)/
      TTL            = 180
      NONCE          = 'nonce'
      RESPONSE       = 'response'
      BAD_NONCE      = 'Bad nonce'
      
      def initialize app, rails_application, store
        @rails_application = rails_application
        rails_application.config.escrow = self
        @app   = app
        @store = store
        @recognized_escrow_segments = []
      end

      def call env
        if serve_from_escrow? env
          # No need to call the Rails app if we're serving a response from escrow
          response_from_escrow env
        else
          status, header, response = @app.call env

          if keep_in_escrow? env
            id, nonce = store_in_escrow status, header, response

            # HTTP Status Code 303 - See Other
            redirect_to = "/escrow/#{id}/#{nonce}"
            [ 303, header.merge(LOCATION => redirect_to), [ "Escrowed at #{redirect_to}" ] ]
          else
            [ status, header, response ]
          end
        end
      end

      def recognize_escrow segment
        @recognized_escrow_segments.push segment
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
        nonce = ActiveSupport::SecureRandom.hex(4)

        response_body = []
        response.each { |content| response_body.push(content) }
        value = {
          NONCE    => nonce,
          RESPONSE => [ status, header, [ response_body.join ] ]
        }

        # Serialze the nonce and Rack response triplet
        # and store in Redis
        key = escrow_key id
        resolved_store.set key, value.to_json

        # Set TTL on secure response
        resolved_store.expire key, TTL

        [ id, nonce ]
      end

      def serve_from_escrow? env
        return false unless GET == env[REQUEST_METHOD]
        id, nonce = escrow_id_and_nonce env
        key = escrow_key id
        resolved_store.exists key
      end

      def response_from_escrow env
        id, nonce = escrow_id_and_nonce env
        key = escrow_key id
        value = JSON.parse(resolved_store.get key)

        if nonce == value[NONCE]
          # Destroy the stored value
          resolved_store.del key
          value[RESPONSE]
        else
          # HTTP Status Code 403 - Forbidden
          [ 403, {}, [ BAD_NONCE ] ]
        end
      end

      def resolved_store
        @resolved_store ||= @store.call
      end

      def escrow_key id
        "escrow:#{id}"
      end

      def escrow_id_and_nonce env
        match = env[REQUEST_PATH].match ESCROW_MATCH
        match && match[1..2]
      end
    end
  end
end

