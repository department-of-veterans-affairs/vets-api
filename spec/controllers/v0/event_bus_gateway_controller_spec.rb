# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::EventBusGatewayController, type: :controller do
  let(:service_account_access_token) { create(:service_account_access_token, scopes: ['http://www.example.com/v0/event_bus_gateway/send_email'], user_attributes: { 'participant_id' => '123456789' }) }
  let(:access_token) { SignIn::ServiceAccountAccessTokenJwtEncoder.new(service_account_access_token:).perform }

  before do
    request.headers['Authorization'] = "Bearer #{access_token}"
  end

  describe 'POST #send_email' do

    context 'with EP120 and feature flag enabled' do
      let(:params) { { template_id: '5678', ep_code: 'EP120' } }

      before do
        allow(Flipper).to receive(:enabled?).with(:ep120_decision_letter_notifications).and_return(true)
      end

      it 'invokes the letter ready email job' do
        expect(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async).with('123456789', '5678', 'EP120')
        post :send_email, params: params
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with EP120 and feature flag disabled' do
      let(:params) { { template_id: '5678', ep_code: 'EP120' } }

      before do
        allow(Flipper).to receive(:enabled?).with(:ep120_decision_letter_notifications).and_return(false)
      end

      it 'does not invoke any email jobs' do
        expect(EventBusGateway::LetterReadyEmailJob).not_to receive(:perform_async)
        post :send_email, params: params
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with 120 and feature flag enabled' do
      let(:params) { { template_id: '5678', ep_code: '120' } }

      before do
        allow(Flipper).to receive(:enabled?).with(:ep120_decision_letter_notifications).and_return(true)
      end

      it 'invokes the letter ready email job' do
        expect(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async).with('123456789', '5678', '120')
        post :send_email, params: params
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with EP180 and feature flag enabled' do
      let(:params) { { template_id: '5678', ep_code: 'EP180' } }

      before do
        allow(Flipper).to receive(:enabled?).with(:ep180_decision_letter_notifications).and_return(true)
      end

      it 'invokes the letter ready email job' do
        expect(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async).with('123456789', '5678', 'EP180')
        post :send_email, params: params
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with EP180 and feature flag disabled' do
      let(:params) { { template_id: '5678', ep_code: 'EP180' } }

      before do
        allow(Flipper).to receive(:enabled?).with(:ep180_decision_letter_notifications).and_return(false)
      end

      it 'does not invoke any email jobs' do
        expect(EventBusGateway::LetterReadyEmailJob).not_to receive(:perform_async)
        post :send_email, params: params
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with 180 and feature flag enabled' do
      let(:params) { { template_id: '5678', ep_code: '180' } }

      before do
        allow(Flipper).to receive(:enabled?).with(:ep180_decision_letter_notifications).and_return(true)
      end

      it 'invokes the letter ready email job' do
        expect(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async).with('123456789', '5678', '180')
        post :send_email, params: params
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with regular decision letter (EP110)' do
      let(:params) { { template_id: '5678', ep_code: 'EP110' } }

      it 'invokes the letter ready email job' do
        expect(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async).with('123456789', '5678', 'EP110')
        post :send_email, params: params
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with missing ep_code' do
      let(:params) { { template_id: '5678' } }

      it 'returns a bad request error' do
        post :send_email, params: params
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'ep_code is required' })
      end
    end

    context 'with empty ep_code' do
      let(:params) { { template_id: '5678', ep_code: '' } }

      it 'returns a bad request error' do
        post :send_email, params: params
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'ep_code is required' })
      end
    end

    context 'with missing template_id' do
      let(:params) { { ep_code: 'EP110' } }

      it 'returns a bad request error' do
        post :send_email, params: params
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'template_id is required' })
      end
    end
  end
end