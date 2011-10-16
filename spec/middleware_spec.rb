require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe 'SecureEscrow::Middleware' do
  let(:app) { MockEngine.new }
  let(:store) { MockRedis.new }
  let(:middleware) { SecureEscrow::Middleware.new app, store }

  it 'should be callable' do
    middleware.should respond_to(:call).with(1).argument
  end
end

