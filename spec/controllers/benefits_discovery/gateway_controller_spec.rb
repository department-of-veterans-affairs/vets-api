# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitsDiscovery::GatewayController, type: :request do
  let(:service_instance) { instance_double(BenefitsDiscovery::Service) }
  let(:headers) do
    {
      'x-api-key' => 'custom_api_key',
      'x-app-id' => 'custom_app_id'
    }
  end
  let(:request_params) { { dateOfBirth: '1990-01-01' } }
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
    allow(service_instance).to receive(:proxy_request).and_return(response_data)
    allow(Flipper).to receive(:enabled?).with(:bds_gateway_enabled).and_return(true)
  end

  describe 'GET #proxy' do
    before do
      allow(service_instance).to receive(:proxy_request).and_return(response_data)
      allow(Flipper).to receive(:enabled?).with(:bds_gateway_enabled).and_return(true)
    end

    it 'proxies GET requests to /benefits_discovery/v0/benefits' do
      expect(service_instance).to receive(:proxy_request).with(method: :get, path: 'v0/benefits', body: nil)
      get '/benefits_discovery/v0/benefits', headers:
    end

    it 'returns successful response for GET' do
      get('/benefits_discovery/v0/benefits', headers:)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(response_data)
    end

    context 'when service raises an error on GET' do
      before do
        allow(service_instance).to receive(:proxy_request).and_raise(StandardError, 'Service error')
      end

      it 'returns error response for GET' do
        get('/benefits_discovery/v0/benefits', headers:)
        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Service error' })
      end
    end
  end

  describe 'POST #proxy' do
    context 'with API headers' do
      it 'uses custom headers for service initialization' do
        expect(BenefitsDiscovery::Service).to receive(:new).with(
          api_key: 'custom_api_key',
          app_id: 'custom_app_id'
        )

        post '/benefits_discovery/v0/recommendations', params: request_params, headers:
      end

      it 'returns successful response' do
        post('/benefits_discovery/v0/recommendations', params: request_params, headers:)

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(response_data)
      end
    end

    context 'without custom api key but with valid app_id' do
      let(:headers) do
        { 'x-app-id' => Settings.lighthouse.benefits_discovery.transition_experience_app_id }
      end

      it 'uses app-specific API key from settings' do
        expect(BenefitsDiscovery::Service).to receive(:new).with(
          api_key: Settings.lighthouse.benefits_discovery.transition_experience_api_key,
          app_id: Settings.lighthouse.benefits_discovery.transition_experience_app_id
        )

        post '/benefits_discovery/v0/recommendations', params: request_params, headers:
      end

      it 'returns successful response' do
        post('/benefits_discovery/v0/recommendations', params: request_params, headers:)

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(response_data)
      end
    end

    context 'with unsupported app_id' do
      let(:headers) do
        { 'x-app-id' => 'unsupported-app' }
      end

      it 'returns error for unsupported app_id' do
        post('/benefits_discovery/v0/recommendations', params: request_params, headers:)

        expect(response).to have_http_status(:internal_server_error)
        response_body = JSON.parse(response.body)
        expect(response_body['error']).to include('Unsupported app_id')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/BDSGateway recommendations error/)
        post '/benefits_discovery/v0/recommendations', params: request_params, headers:
      end
    end

    context 'with valid parameters' do
      let(:params) do
        {
          'dateOfBirth' => '1995-01-01',
          'disabilityRating' => '60',
          'serviceHistory' => [
            {
              'startDate' => '2002-03-15',
              'endDate' => '2006-08-31',
              'dischargeStatus' => 'HONORABLE_DISCHARGE',
              'branchOfService' => 'NAVY'
            },
            {
              'startDate' => '2007-04-03',
              'endDate' => '2010-12-31',
              'dischargeStatus' => 'GENERAL_DISCHARGE',
              'branchOfService' => 'ARMY'
            }
          ],
          'purpleHeartRecipientDates' => %w[
            2003-02-01
            2005-05-13
          ]
        }
      end

      let(:headers) do
        {
          'x-api-key' => 'test-api-key',
          'x-app-id' => 'test-app'
        }
      end

      it 'passes parameters to service' do
        expect(service_instance).to receive(:proxy_request).with(method: :post,
                                                                 path: 'v0/recommendations',
                                                                 body: params)

        post '/benefits_discovery/v0/recommendations', params:, headers:
      end
    end

    context 'when service raises an error' do
      before do
        allow(service_instance).to receive(:proxy_request).and_raise(StandardError, 'Service error')
      end

      let(:headers) do
        {
          'x-api-key' => 'test-api-key',
          'x-app-id' => 'test-app'
        }
      end

      it 'returns error response' do
        post('/benefits_discovery/v0/recommendations', params: request_params, headers:)

        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Service error' })
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with('BDSGateway recommendations error: Service error')

        post '/benefits_discovery/v0/recommendations', params: request_params
      end
    end

    context 'when flipper is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:bds_gateway_enabled).and_return(false)
      end

      let(:headers) do
        {
          'x-api-key' => 'test-api-key',
          'x-app-id' => 'test-app'
        }
      end

      it 'returns 404 not found' do
        post('/benefits_discovery/v0/recommendations', params: request_params, headers:)

        expect(response).to have_http_status(:not_found)
      end

      it 'does not call the service' do
        expect(BenefitsDiscovery::Service).not_to receive(:new)

        post '/benefits_discovery/v0/recommendations', params: request_params, headers:
      end
    end

    context 'when flipper is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:bds_gateway_enabled).and_return(true)
      end

      let(:headers) do
        {
          'x-api-key' => 'test-api-key',
          'x-app-id' => 'test-app'
        }
      end

      it 'allows the request to proceed' do
        post('/benefits_discovery/v0/recommendations', params: request_params, headers:)

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(response_data)
      end

      it 'calls the service' do
        expect(BenefitsDiscovery::Service).to receive(:new).with(
          api_key: 'test-api-key',
          app_id: 'test-app'
        )

        post '/benefits_discovery/v0/recommendations', params: request_params, headers:
      end
    end
  end
end
