# Attempt to provide engine to Rails
require "secure_escrow/engine"

require "secure_escrow/version"
require "secure_escrow/railtie"
require "secure_escrow/middleware"

module SecureEscrow
  def self.included base
    base.extend ClassMethods
  end
end

