require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe 'SecureEscrow::Middleware' do
  let(:app) { MockEngine.new }
  let(:store) { MockRedis.new }
  let(:middleware) { SecureEscrow::Middleware.new app, store }
  let(:env_keep) { {} }
  let(:env_serve) { {} }
  let(:env_pass) { {} }

  it 'should be callable' do
    middleware.should respond_to(:call).with(1).argument
  end

  it 'should check whether to keep a request in escrow' do
    middleware.should_receive(:serve_from_escrow?).with(env_pass)
    middleware.call env_pass
  end
end

