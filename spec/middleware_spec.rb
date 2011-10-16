require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe 'SecureEscrow::Middleware' do
  let(:app) { MockEngine.new }
  let(:store) { MockRedis.new }
  let(:middleware) { SecureEscrow::Middleware.new app, store }
  let(:presenter) { SecureEscrow::Middleware::Presenter.new app, env }
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
          once.and_return(true)

        presenter.should_receive(:serve_response_from_escrow!).
          once

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


end

