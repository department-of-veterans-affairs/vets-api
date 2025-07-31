# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::BdsGatewayController, type: :controller do
  let(:service_instance) { instance_double(BenefitsDiscovery::Service) }
  let(:response_data) do
    {
      'undetermined' => [],
      'recommended' => [
        {
          'benefit_name' => 'Health',
          'benefit_url' => 'https://www.va.gov/health-care/'
        }
      ],
      'not_recommended' => []
    }
  end

  before do
    allow(BenefitsDiscovery::Service).to receive(:new).and_return(service_instance)
    allow(service_instance).to receive(:get_eligible_benefits).and_return(response_data)
    allow(Flipper).to receive(:enabled?).with(:bds_gateway_enabled).and_return(true)
  end

  describe 'POST #recommendations' do
    context 'with custom headers' do
      let(:custom_api_key) { 'custom-api-key' }
      let(:custom_app_id) { 'custom-app-id' }

      before do
        request.headers['x-api-key'] = custom_api_key
        request.headers['x-app-id'] = custom_app_id
      end

      it 'uses custom headers for service initialization' do
        expect(BenefitsDiscovery::Service).to receive(:new).with(
          api_key: custom_api_key,
          app_id: custom_app_id
        )

        post :recommendations, params: { dateOfBirth: '1990-01-01' }
      end

      it 'returns successful response' do
        post :recommendations, params: { dateOfBirth: '1990-01-01' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(response_data)
      end
    end

    context 'without custom api key but with valid app_id' do
      before do
        request.headers['x-app-id'] = Settings.lighthouse.benefits_discovery.transition_experience_app_id
      end

      it 'uses app-specific API key from settings' do
        expect(BenefitsDiscovery::Service).to receive(:new).with(
          api_key: Settings.lighthouse.benefits_discovery.transition_experience_api_key,
          app_id: Settings.lighthouse.benefits_discovery.transition_experience_app_id
        )

        post :recommendations, params: { dateOfBirth: '1990-01-01' }
      end

      it 'returns successful response' do
        post :recommendations, params: { dateOfBirth: '1990-01-01' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(response_data)
      end
    end

    context 'with unsupported app_id' do
      before do
        request.headers['x-app-id'] = 'unsupported-app'
      end

      it 'returns error for unsupported app_id' do
        post :recommendations, params: { dateOfBirth: '1990-01-01' }

        expect(response).to have_http_status(:internal_server_error)
        response_body = JSON.parse(response.body)
        expect(response_body['error']).to include('Unsupported app_id')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/BDSGateway recommendations error/)
        post :recommendations, params: { dateOfBirth: '1990-01-01' }
      end
    end

    context 'with valid parameters' do
      let(:params) do
        {
          dateOfBirth: '1990-01-01',
          dischargeStatus: ['HONORABLE_DISCHARGE'],
          branchOfService: ['NAVY'],
          disabilityRating: 60,
          serviceDates: [{ startDate: '2018-01-01', endDate: '2022-01-01' }]
        }
      end

      before do
        request.headers['x-api-key'] = 'test-api-key'
        request.headers['x-app-id'] = 'test-app'
      end

      it 'passes parameters to service' do
        # Rails automatically converts form parameters to strings
        expected_params = ActionController::Parameters.new({
          dateOfBirth: '1990-01-01',
          dischargeStatus: ['HONORABLE_DISCHARGE'],
          branchOfService: ['NAVY'],
          disabilityRating: '60', # Note: string, not integer due to Rails param conversion
          serviceDates: [{ startDate: '2018-01-01', endDate: '2022-01-01' }]
        }).permit(:dateOfBirth, :disabilityRating, 
                  dischargeStatus: [], branchOfService: [], 
                  serviceDates: [:startDate, :endDate])

        expect(service_instance).to receive(:get_eligible_benefits).with(expected_params)

        post :recommendations, params: params
      end
    end

    context 'when service raises an error' do
      before do
        request.headers['x-api-key'] = 'test-api-key'
        request.headers['x-app-id'] = 'test-app'
        allow(service_instance).to receive(:get_eligible_benefits).and_raise(StandardError, 'Service error')
      end

      it 'returns error response' do
        post :recommendations, params: { dateOfBirth: '1990-01-01' }

        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Service error' })
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with('BDSGateway recommendations error: Service error')
        post :recommendations, params: { dateOfBirth: '1990-01-01' }
      end
    end

    context 'when flipper is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:bds_gateway_enabled).and_return(false)
        request.headers['x-api-key'] = 'test-api-key'
        request.headers['x-app-id'] = 'test-app'
      end

      it 'returns 404 not found' do
        post :recommendations, params: { dateOfBirth: '1990-01-01' }

        expect(response).to have_http_status(:not_found)
      end

      it 'does not call the service' do
        expect(BenefitsDiscovery::Service).not_to receive(:new)

        post :recommendations, params: { dateOfBirth: '1990-01-01' }
      end
    end

    context 'when flipper is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:bds_gateway_enabled).and_return(true)
        request.headers['x-api-key'] = 'test-api-key'
        request.headers['x-app-id'] = 'test-app'
      end

      it 'allows the request to proceed' do
        post :recommendations, params: { dateOfBirth: '1990-01-01' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(response_data)
      end

      it 'calls the service' do
        expect(BenefitsDiscovery::Service).to receive(:new).with(
          api_key: 'test-api-key',
          app_id: 'test-app'
        )

        post :recommendations, params: { dateOfBirth: '1990-01-01' }
      end
    end
  end
end
