require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))
include SecureEscrow::MiddlewareConstants

describe 'SecureEscrow::Middleware' do
  let(:app) { MockEngine.new }
  let(:store) { MockRedis.new }
  let(:middleware) { SecureEscrow::Middleware.new app, store }
  let(:presenter) { SecureEscrow::Middleware::Presenter.new app, store, env }
  let(:env) { {} }

  context 'as a Rack application' do
    it 'should be callable' do
      middleware.should respond_to(:call).with(1).argument
    end

    it 'should handle_presenter with wrapped environment' do
      middleware.should_receive(:presenter).with(env).
        once.and_return(presenter)

      middleware.should_receive(:handle_presenter).with(presenter).once

      middleware.call(env)
    end

    context 'when handling the presenter' do
      it 'should first serve a response from escrow' do
        presenter.should_receive(:serve_response_from_escrow?).
          with.once.and_return(true)

        presenter.should_receive(:serve_response_from_escrow!).
          with.once

        presenter.should_not_receive(:store_response_in_escrow_and_redirect!)
        presenter.should_not_receive(:serve_response_from_application!)

        middleware.handle_presenter presenter
      end

      it 'should store a response in the escrow and redirect' do
        presenter.should_receive(:serve_response_from_escrow?).
          once.and_return(false)
        presenter.should_receive(:store_response_in_escrow?).
          once.and_return(true)
        presenter.should_receive(:store_response_in_escrow_and_redirect!).
          once

        presenter.should_not_receive(:serve_response_from_escrow!)
        presenter.should_not_receive(:serve_response_from_application!)

        middleware.handle_presenter presenter
      end

      it 'should pass-through other requests' do
        presenter.should_receive(:serve_response_from_escrow?).
          once.and_return(false)
        presenter.should_receive(:store_response_in_escrow?).
          once.and_return(false)
        presenter.should_receive(:serve_response_from_application!).
          once

        presenter.should_not_receive(:serve_response_from_escrow!)
        presenter.should_not_receive(:store_response_in_escrow_and_redirect!)

        middleware.handle_presenter presenter
      end
    end
  end

  context 'Presenter' do
    describe 'serve_response_from_escrow?' do
      it 'should not serve POSTs' do
        presenter.env[REQUEST_METHOD] = POST
        presenter.serve_response_from_escrow?.should be_false
      end

      it 'should not serve responses where the escrow key is not in the store' do
        presenter.env[REQUEST_METHOD] = GET
        set_escrow_cookie presenter, 'id'

        presenter.serve_response_from_escrow?.should be_false
      end

      it 'should not check the backing store when no escrow param is present' do
        presenter.env[REQUEST_METHOD] = GET

        store.should_not_receive(:exists)
        presenter.serve_response_from_escrow?
      end

      it 'should serve responses where the escrow key is in the store' do
        presenter.env[REQUEST_METHOD] = GET
        store_in_escrow store, 'id'

        set_escrow_cookie presenter, 'id'
        presenter.serve_response_from_escrow?.should be_true
      end
    end

    describe 'store_response_in_escrow?' do
      it 'should not store GETs' do
        presenter.env[REQUEST_METHOD] = GET
        presenter.store_response_in_escrow?.should be_false
      end

      it 'should not store non-existent routes' do
        presenter.env[REQUEST_METHOD] = POST

        app.routes.should_receive(:recognize_path).
          once.with(env[REQUEST_PATH], { method: POST }).
          and_raise(
            ActionController::RoutingError.new("No route matches #{env[REQUEST_PATH]}")
          )

        presenter.store_response_in_escrow?.should be_false
      end

      it 'should not store non-escrow routes' do
        presenter.env[REQUEST_METHOD] = POST

        app.routes.should_receive(:recognize_path).
          once.with(env[REQUEST_PATH], { method: POST }).
          and_return(controller: 'session', action: 'create')

        presenter.store_response_in_escrow?.should be_false
      end

      it 'should store escrow routes' do
        presenter.env[REQUEST_METHOD] = POST

        app.routes.should_receive(:recognize_path).
          once.with(env[REQUEST_PATH], { method: POST }).
          and_return(controller: 'session', action: 'create', escrow: true)

        presenter.store_response_in_escrow?.should be_true
      end
    end

    describe 'serve_response_from_escrow!' do
      it 'should return 403 - Forbidden when nonce does not match' do
        store_in_escrow store, 'id', 'good-nonce', []

        set_escrow_cookie presenter, 'id', 'bad-nonce'
        presenter.serve_response_from_escrow![0].should eq 403
      end

      it 'should delete the key from the backing store' do
        store_in_escrow store, 'id'
        set_escrow_cookie presenter, 'id'

        store.should_receive(:del).
          once.with(presenter.escrow_key('id'))

        presenter.serve_response_from_escrow!
      end

      it 'should return the escrowed response' do
        response = [ 200, {}, [ 'text' ] ]
        store_in_escrow store, 'id', 'nonce', response
        set_escrow_cookie presenter, 'id', 'nonce'

        presenter.serve_response_from_escrow!.should == response
      end
    end

    describe 'escrow_id and escrow_nonce' do
      context 'when insecure_domain_name is different from secure_domain_name' do
        let(:app) {
          MockEngine.new(
            secure_domain_name:   'www.ssl-example.com',
            insecure_domain_name: 'www.example.com'
          )
        }

        it 'should recognize escrow id and nonce from query string' do
          presenter.env[QUERY_STRING] = "#{SecureEscrow::MiddlewareConstants::DATA_KEY}=id.nonce"
          presenter.escrow_id.should    eq 'id'
          presenter.escrow_nonce.should eq 'nonce'
        end
      end

      context 'when insecure_domain_name is the same as secure_domain_name' do
        let(:app) {
          MockEngine.new(
            secure_domain_name:   'www.example.com',
            insecure_domain_name: 'www.example.com'
          )
        }

        it 'should recognize escrow id from cookie' do
          presenter.env[HTTP_COOKIE] = "#{SecureEscrow::MiddlewareConstants::DATA_KEY}=id.nonce"
          presenter.escrow_id.should    eq 'id'
          presenter.escrow_nonce.should eq 'nonce'
        end
      end

    end
  end

end

def set_escrow_cookie presenter, id = 'id', nonce = 'nonce'
  presenter.env[HTTP_COOKIE] = "%s=%s.%s" % [
    SecureEscrow::MiddlewareConstants::DATA_KEY,
    id, nonce
  ]
end

def store_in_escrow store, id = 'id', nonce = 'nonce', response = []
  store.set(presenter.escrow_key(id), ActiveSupport::JSON.encode(NONCE => nonce, RESPONSE => response))
end

