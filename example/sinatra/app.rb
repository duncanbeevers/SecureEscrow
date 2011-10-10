require 'sinatra'
require File.expand_path(File.join(File.dirname(__FILE__), '../../lib/rack/escrow'))

# use Rack::Escrow

class SinatraExampleApp < Sinatra::Base
  get '/' do
    erb :index
  end

  post '/create_session' do
    
  end
end

