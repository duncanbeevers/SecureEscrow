require 'spork'

Spork.prefork do
  require 'rspec'
  require 'pry-remote'
end

Spork.each_run do
  require 'rack-ssl-escrow'
end

