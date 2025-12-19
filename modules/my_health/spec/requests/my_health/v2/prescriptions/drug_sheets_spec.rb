# frozen_string_literal: true

require 'rails_helper'
require 'support/rx_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V2::Prescriptions::DrugSheets', type: :request do
  include Rx::ClientHelpers

  let(:va_patient) { true }
  let(:current_user) do
    build(:user, :mhv, sign_in: { service_name: SignIn::Constants::Auth::IDME })
  end

  before do
    allow(Rx::Client).to receive(:new).and_return(authenticated_client)
    sign_in_as(current_user)
  end

  describe 'POST /my_health/v2/prescriptions/drug_sheets/search' do
    context 'when NDC is provided' do
      it 'responds to POST /my_health/v2/prescriptions/drug_sheets/search' do
        VCR.use_cassette('rx_client/prescriptions/rx_documentation_search') do
          post '/my_health/v2/prescriptions/drug_sheets/search', params: { ndc: '00013264681' }

          expect(response).to be_successful
          expect(response.body).to be_a(String)
        end
      end

      it 'returns prescription documentation in JSON format' do
        VCR.use_cassette('rx_client/prescriptions/rx_documentation_search') do
          post '/my_health/v2/prescriptions/drug_sheets/search', params: { ndc: '00013264681' }

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to eq('application/json; charset=utf-8')
        end
      end

      it 'returns documentation with html attribute' do
        VCR.use_cassette('rx_client/prescriptions/rx_documentation_search') do
          post '/my_health/v2/prescriptions/drug_sheets/search', params: { ndc: '00013264681' }

          json_response = JSON.parse(response.body)
          expect(json_response).to have_key('data')
          expect(json_response['data']).to have_key('attributes')
          expect(json_response['data']['attributes']).to have_key('html')
          expect(json_response['data']['attributes']['html']).to be_a(String)
          expect(json_response['data']['attributes']['html']).to include('Somatropin')
        end
      end
    end

    context 'when NDC is missing' do
      it 'returns bad request error' do
        post '/my_health/v2/prescriptions/drug_sheets/search', params: {}

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']['code']).to eq('NDC_REQUIRED')
        expect(json_response['error']['message']).to eq('NDC number is required')
      end
    end

    context 'when NDC is blank' do
      it 'returns bad request error' do
        post '/my_health/v2/prescriptions/drug_sheets/search', params: { ndc: '' }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']['code']).to eq('NDC_REQUIRED')
        expect(json_response['error']['message']).to eq('NDC number is required')
      end
    end

    context 'when documentation is not found (404)' do
      before do
        backend_exception = Common::Exceptions::BackendServiceException.new(
          'RX_404',
          { status: 404, detail: 'Not found', code: 'RX_404' },
          404,
          'Not found'
        )
        allow_any_instance_of(Rx::Client).to receive(:get_rx_documentation).and_raise(backend_exception)
      end

      it 'returns not found error' do
        post '/my_health/v2/prescriptions/drug_sheets/search', params: { ndc: '99999999999' }

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']['code']).to eq('DOCUMENTATION_NOT_FOUND')
        expect(json_response['error']['message']).to eq('Documentation not found for this NDC')
      end
    end

    context 'when client raises an error' do
      before do
        allow_any_instance_of(Rx::Client).to receive(:get_rx_documentation).and_raise(StandardError, 'API Error')
      end

      it 'returns service unavailable error' do
        post '/my_health/v2/prescriptions/drug_sheets/search', params: { ndc: '00013264681' }

        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']['code']).to eq('SERVICE_UNAVAILABLE')
        expect(json_response['error']['message']).to eq('Unable to fetch documentation')
      end
    end
  end
end
