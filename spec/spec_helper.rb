require 'spork'

Spork.prefork do
  require 'rspec'
  require 'pry-remote'
  require 'active_support/json'
  require 'action_controller'

  RSpec.configure do |config|
  end
end

Spork.each_run do
  require 'secure_escrow'

  # Load mocks
  require 'mock_engine'
  require 'mock_redis'
  require 'mock_rack_app'
end

