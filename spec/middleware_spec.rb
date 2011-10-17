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

  context 'SecureEscrow::Middleware::Presenter' do
    it 'should not store GETs' do
      presenter.env[REQUEST_METHOD] = GET
      presenter.store_response_in_escrow?.should be_false
    end

    context 'when recognizing requests for content from the escrow' do
      context 'when insecure_domain_name is different from secure_domain_name' do
        let(:app) {
          MockEngine.new(
            secure_domain_name:   'www.ssl-example.com',
            insecure_domain_name: 'www.example.com'
          )
        }

        it 'should recognize escrow id from query string' do
          presenter.env[QUERY_STRING] = "#{SecureEscrow::MiddlewareConstants::DATA_KEY}=id.nonce"
          presenter.escrow_id.should == 'id'
        end

        it 'should recognize escrow nonce from query string' do
          presenter.env[QUERY_STRING] = "#{SecureEscrow::MiddlewareConstants::DATA_KEY}=id.nonce"
          presenter.escrow_nonce.should == 'nonce'
        end
      end

      context 'when insecure_domain_name is the same as secure_domain_name' do
        it 'should recognize escrow id from cookie' do
          presenter.env[HTTP_COOKIE] = "#{SecureEscrow::MiddlewareConstants::DATA_KEY}=id.nonce"
          presenter.escrow_id.should == 'id'
        end

        it 'should recognize escrow nonce from cookie' do
          presenter.env[HTTP_COOKIE] = "#{SecureEscrow::MiddlewareConstants::DATA_KEY}=id.nonce"
          presenter.escrow_nonce.should == 'nonce'
        end
      end
    end
  end

end

