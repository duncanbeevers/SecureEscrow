require 'spork'

Spork.prefork do
  require 'rspec'
  require 'pry-remote'
  require 'active_support/json'

  RSpec.configure do |config|
  end
end

Spork.each_run do
  require 'secure_escrow'

  # Load mocks
  require 'mock_engine'
  require 'mock_redis'
end

