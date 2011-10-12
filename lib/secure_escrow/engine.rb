# Register as a Rails engine
# in order to hook into asset pipeline
module SecureEscrow
  begin
    class Engine < ::Rails::Engine
      initializer :extend_routing do |app|
        app.routes.extend SecureEscrow::Railtie::Routing
        ActionController::Base.helper SecureEscrow::Railtie::ActionViewHelper
      end
    end
  rescue NameError
  end
end

