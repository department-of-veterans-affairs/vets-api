# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyHealth::MHVControllerConcerns, type: :controller do
  controller(ApplicationController) do
    include MyHealth::MHVControllerConcerns

    def index
      render json: { success: true }
    end

    protected

    def client
      @client ||= double('Client')
    end

    def authorize
      raise Common::Exceptions::Forbidden, detail: 'Not authorized' unless @authorized
    end
  end

  let(:mhv_id) { '12345678' }
  let(:user) { build(:user, :mhv, mhv_correlation_id: mhv_id) }
  let(:mock_client) { double('Client', authenticate: true) }

  before do
    sign_in_as(user)
    routes.draw { get 'index' => 'anonymous#index' }
  end

  describe 'before_action chain' do
    context 'when all validations pass' do
      before do
        @authorized = true
        allow(controller).to receive(:client).and_return(mock_client)
      end

      it 'executes all before_actions in correct order' do
        expect(controller).to receive(:validate_mhv_correlation_id).ordered.and_call_original
        expect(controller).to receive(:authorize).ordered.and_call_original
        expect(controller).to receive(:authenticate_client).ordered.and_call_original

        get :index

        expect(response).to have_http_status(:ok)
      end

      it 'calls client.authenticate' do
        expect(mock_client).to receive(:authenticate)
        get :index
      end

      it 'renders successfully' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq('success' => true)
      end
    end

    context 'when mhv_correlation_id is missing' do
      let(:mhv_id) { nil }

      before do
        @authorized = true
        allow(controller).to receive(:client).and_return(mock_client)
      end

      it 'fails at validate_mhv_correlation_id before calling authorize' do
        expect(controller).to receive(:validate_mhv_correlation_id).and_call_original
        expect(controller).not_to receive(:authorize)
        expect(controller).not_to receive(:authenticate_client)

        get :index
      end

      it 'returns unprocessable entity' do
        get :index
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not call client.authenticate' do
        expect(mock_client).not_to receive(:authenticate)
        get :index
      end

      it 'logs error with user context' do
        expect(Rails.logger).to receive(:error).with(
          'MHV correlation ID missing for authenticated user',
          hash_including(
            user_uuid: user.uuid,
            controller: 'AnonymousController',
            action: 'index'
          )
        )
        get :index
      end
    end

    context 'when mhv_correlation_id is blank string' do
      let(:mhv_id) { '' }

      before do
        @authorized = true
      end

      it 'returns unprocessable entity' do
        get :index
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when authorization fails' do
      before do
        @authorized = false
        allow(controller).to receive(:client).and_return(mock_client)
      end

      it 'fails at authorize before calling authenticate_client' do
        expect(controller).to receive(:validate_mhv_correlation_id).and_call_original
        expect(controller).to receive(:authorize).and_call_original
        expect(controller).not_to receive(:authenticate_client)

        expect { get :index }.to raise_error(Common::Exceptions::Forbidden)
      end

      it 'does not call client.authenticate' do
        expect(mock_client).not_to receive(:authenticate)
        expect { get :index }.to raise_error(Common::Exceptions::Forbidden)
      end
    end

    context 'when client authentication fails' do
      before do
        @authorized = true
        allow(controller).to receive(:client).and_return(mock_client)
        allow(mock_client).to receive(:authenticate).and_raise(StandardError, 'Auth failed')
      end

      it 'executes validate and authorize before failing at authenticate_client' do
        expect(controller).to receive(:validate_mhv_correlation_id).and_call_original
        expect(controller).to receive(:authorize).and_call_original
        expect(controller).to receive(:authenticate_client).and_call_original

        expect { get :index }.to raise_error(StandardError, 'Auth failed')
      end

      it 'calls client.authenticate which raises error' do
        expect(mock_client).to receive(:authenticate).and_raise(StandardError, 'Auth failed')
        expect { get :index }.to raise_error(StandardError, 'Auth failed')
      end
    end
  end

  describe '#validate_mhv_correlation_id' do
    context 'with valid mhv_correlation_id' do
      let(:mhv_id) { '12345678' }

      before do
        @authorized = true
        allow(controller).to receive(:client).and_return(mock_client)
      end

      it 'allows the request to proceed' do
        get :index
        expect(response).to have_http_status(:ok)
      end

      it 'does not log any errors' do
        expect(Rails.logger).not_to receive(:error)
        get :index
      end
    end

    context 'without mhv_correlation_id' do
      let(:mhv_id) { nil }

      it 'returns unprocessable entity error' do
        get :index
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'includes user-friendly error message' do
        get :index
        error = JSON.parse(response.body)['errors'].first
        expect(error['detail']).to eq('Unable to access MHV services. Please try signing in again.')
      end

      it 'logs comprehensive error details' do
        expect(Rails.logger).to receive(:error).with(
          'MHV correlation ID missing for authenticated user',
          hash_including(
            user_uuid: user.uuid,
            icn: user.icn,
            sign_in_service: user.identity&.sign_in&.dig(:service_name),
            loa: user.loa,
            controller: 'AnonymousController',
            action: 'index'
          )
        )
        get :index
      end
    end
  end

  describe '#authenticate_client' do
    before do
      @authorized = true
      allow(controller).to receive(:client).and_return(mock_client)
    end

    it 'calls authenticate on the client' do
      expect(mock_client).to receive(:authenticate).once
      get :index
    end

    it 'is called after validate and authorize' do
      expect(controller).to receive(:validate_mhv_correlation_id).ordered.and_call_original
      expect(controller).to receive(:authorize).ordered.and_call_original
      expect(mock_client).to receive(:authenticate).ordered

      get :index
    end
  end
end
