# Register as a Rails engine
# in order to hook into asset pipeline
module SecureEscrow
  begin
    class Engine < ::Rails::Engine
      initializer :setup_escrow do |app|
        # Mix view helpers in through ActionController
        ActionController::Base.helper SecureEscrow::Railtie::ActionViewHelper

        # Mix routing helpers in through the Mapper class
        ActionDispatch::Routing::Mapper.send(:include, routing_extensions(self))

        @registered_segments = []
      end

      def register_escrow_segment segment
        @registered_segments.push segment
      end

      private
      # The routing helper includes an escrow method usable by
      # routing mapper, and also creates a dynamically-scoped
      # register_escrow_segment_with_engine method bound to
      # the engine's register_escrow_segment method
      def routing_extensions engine
        register = engine.method :register_escrow_segment
        Module.new do
          include SecureEscrow::Railtie::Routing
          define_method :register_escrow_segment_with_engine do |segment|
            register.call segment
          end
        end
      end

    end
  rescue NameError
  end
end

