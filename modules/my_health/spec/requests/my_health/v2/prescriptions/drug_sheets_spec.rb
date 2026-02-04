# frozen_string_literal: true

require 'rails_helper'
require 'support/rx_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V2::Prescriptions::DrugSheets', type: :request do
  include Rx::ClientHelpers

  let(:va_patient) { true }
  let(:current_user) do
    build(:user, :mhv, authn_context: LOA::IDME_LOA3_VETS,
                       va_patient:,
                       sign_in: { service_name: SignIn::Constants::Auth::IDME })
  end

  before do
    allow_any_instance_of(User).to receive(:mhv_user_account).and_return(OpenStruct.new(patient: va_patient))
    allow_any_instance_of(User).to receive(:mhv_correlation_id).and_return('12345678901')
    allow(Rx::Client).to receive(:new).and_return(authenticated_client)
    sign_in_as(current_user)
  end

  context 'when user is unauthorized' do
    let(:current_user) do
      build(:user, :mhv, :no_vha_facilities, authn_context: LOA::IDME_LOA3_VETS, va_patient: true,
                                             sign_in: { service_name: SignIn::Constants::Auth::IDME })
    end

    before do
      allow_any_instance_of(User).to receive(:mhv_user_account).and_return(OpenStruct.new(patient: false,
                                                                                          champ_va: false))
      post '/my_health/v2/prescriptions/drug_sheets/search', params: { ndc: '00013264681' }
    end

    include_examples 'for user account level', message: 'You do not have access to prescriptions'
  end

  context 'when user is authorized' do
    context 'when user is not a va patient' do
      let(:va_patient) { false }
      let(:current_user) do
        build(:user,
              :mhv,
              :no_vha_facilities,
              authn_context: LOA::IDME_LOA3_VETS,
              va_patient:,
              sign_in: { service_name: SignIn::Constants::Auth::IDME })
      end

      before { post '/my_health/v2/prescriptions/drug_sheets/search', params: { ndc: '00013264681' } }

      it 'is NOT authorized' do
        expect(response).not_to be_successful
        expect(response).to have_http_status(:forbidden)
      end
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
        let(:ndc) { '00013264681' }
        let(:error_message) { 'API Error' }
        let(:standard_error) { StandardError.new(error_message) }

        before do
          allow_any_instance_of(Rx::Client).to receive(:get_rx_documentation)
            .and_raise(standard_error)
          allow(Rails.logger).to receive(:error)
        end

        it 'returns service unavailable error' do
          post '/my_health/v2/prescriptions/drug_sheets/search', params: { ndc: }

          expect(response).to have_http_status(:service_unavailable)
          json_response = JSON.parse(response.body)
          expect(json_response).to have_key('error')
          expect(json_response['error']['code']).to eq('SERVICE_UNAVAILABLE')
          expect(json_response['error']['message']).to eq('Unable to fetch documentation')
        end

        it 'logs the error with NDC context, exception class, message, and backtrace' do
          post '/my_health/v2/prescriptions/drug_sheets/search', params: { ndc: }

          expect(Rails.logger).to have_received(:error).with(
            'DrugSheetsController: Failed to fetch documentation',
            hash_including(
              ndc:,
              error_class: 'StandardError',
              error_message:,
              backtrace: kind_of(Array)
            )
          )
        end
      end
    end
  end
end
