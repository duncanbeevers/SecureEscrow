require "rack/escrow/version"
require "rack/escrow/railtie"
require "rack/escrow/middleware"

module Rack
  module Escrow
    def self.included base
      base.extend ClassMethods
    end
  end

  module ClassMethods
    def escrow method
    end
  end
end

