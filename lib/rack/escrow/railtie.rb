require "action_dispatch"

module Rack
  module Escrow
    module Railtie
      module Routing
        def post *args, &block
          options = args.last.kind_of?(Hash) ? args.last : {}
          escrow = options.delete(:escrow)

          # This modifies the options hash that gets supered
          # up to the original post implementation
          mark_escrow!(options, &block) if escrow

          # This may rely on the options hash having been modified
          super(*args, &block)
        end

        private
        def mark_escrow! options, &block
          segment, endpoint = options.select do |k, v|
            k.kind_of?(String)
          end.first

          Rails.application.config.escrow.recognize_escrow segment

          # Mark the Rails routes as escrowed
          # so they can be recognized by the Middleware
          options[:defaults] ||= {}
          options[:defaults][:escrow] = true
        end
      end
    end
  end
end

ActionDispatch::Routing::Mapper.send(:include, Rack::Escrow::Railtie::Routing)

