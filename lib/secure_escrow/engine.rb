require 'rails'

# Register as a Rails engine
# in order to hook into asset pipeline
module SecureEscrow
  class Engine < ::Rails::Engine
    initializer :setup_escrow do |app|
      # Mix view helpers in through ActionController
      ActionController::Base.helper SecureEscrow::Railtie::ActionViewHelper

      # Mix routing helpers in through the Mapper class
      ActionDispatch::Routing::Mapper.send :include, SecureEscrow::Railtie::Routing
    end
  end
end

