# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V1::Health::Prescriptions', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(:mhv, mhv_account_type:) }
  let(:mhv_account_type) { 'Premium' }
  let(:va_patient) { true }
  let(:current_user) { user }

  before do
    allow_any_instance_of(User).to receive(:va_patient?).and_return(va_patient)
    sign_in_as(user)
    allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(true)
  end

  describe 'GET /mobile/v1/health/rx/prescriptions' do
    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/mobile/v1/health/rx/prescriptions'

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with feature flag disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(false)
      end

      it 'returns forbidden error' do
        get '/mobile/v1/health/rx/prescriptions', headers: sis_headers

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']['code']).to eq('FEATURE_NOT_AVAILABLE')
      end
    end

    context 'when user does not have mhv access' do
      let!(:user) { sis_user }

      it 'returns a 403 forbidden response' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          get '/mobile/v1/health/rx/prescriptions', headers: sis_headers
        end
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq({ 'errors' =>
                                             [{ 'title' => 'Forbidden',
                                                'detail' => 'User does not have access to the requested resource',
                                                'code' => '403',
                                                'status' => '403' }] })
      end
    end

    context 'with feature flag enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(true)
      end

      context 'when UHD service returns prescriptions successfully' do
        it 'returns prescriptions with mobile-specific metadata' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            get '/mobile/v1/health/rx/prescriptions', headers: sis_headers

            expect(response).to have_http_status(:ok)
            expect(response.parsed_body).to have_key('data')
            expect(response.parsed_body).to have_key('meta')
            expect(response.parsed_body['meta']).to have_key('pagination')
            expect(response.parsed_body['meta']).to have_key('prescriptionStatusCount')
            expect(response.parsed_body['meta']).to have_key('hasNonVaMeds')

            # Verify that prescription data includes trackingInformation field as empty hash
            expect(response.parsed_body['data']).to be_an(Array)
            if response.parsed_body['data'].any?
              first_prescription = response.parsed_body['data'].first
              expect(first_prescription['attributes']).to have_key('trackingInformation')
              expect(first_prescription['attributes']['trackingInformation']).to eq({})
            end
          end
        end

        it 'handles pagination parameters correctly' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            get '/mobile/v1/health/rx/prescriptions', params: { page: 2, per_page: 10 }, headers: sis_headers

            expect(response).to have_http_status(:ok)
            meta = response.parsed_body['meta']['pagination']
            expect(meta['currentPage']).to eq(2)
            expect(meta['perPage']).to eq(10)
          end
        end

        it 'allows per_page values greater than 50' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            get '/mobile/v1/health/rx/prescriptions', params: { per_page: 100 }, headers: sis_headers

            expect(response).to have_http_status(:ok)
            meta = response.parsed_body['meta']['pagination']
            expect(meta['perPage']).to eq(100)
          end
        end
      end

      context 'when UHD service returns empty results' do
        it 'returns empty array with correct metadata' do
          VCR.use_cassette('unified_health_data/get_prescriptions_empty') do
            get '/mobile/v1/health/rx/prescriptions', headers: sis_headers

            expect(response).to have_http_status(:ok)
            expect(response.parsed_body['data']).to eq([])
            expect(response.parsed_body['meta']['pagination']['totalEntries']).to eq(0)
          end
        end
      end
    end
  end

  describe 'PUT /mobile/v1/health/rx/prescriptions/refill' do
    context 'when user does not have mhv access' do
      let!(:user) { sis_user }

      it 'returns a 403 forbidden response' do
        put '/mobile/v1/health/rx/prescriptions/refill', params: { ids: %w[25804851] }, headers: sis_headers

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq({ 'errors' =>
                                             [{ 'title' => 'Forbidden',
                                                'detail' => 'User does not have access to the requested resource',
                                                'code' => '403',
                                                'status' => '403' }] })
      end
    end

    context 'with feature flag enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(true)
      end

      context 'when refill is successful' do
        it 'returns success response for batch refill' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            VCR.use_cassette('unified_health_data/refill_prescription_success') do
              put '/mobile/v1/health/rx/prescriptions/refill', params: { ids: %w[25804851] }, headers: sis_headers

              expect(response).to have_http_status(:ok)
              expect(response.parsed_body).to have_key('data')

              data = response.parsed_body['data']
              expect(data).to have_key('id')
              expect(data['type']).to eq('PrescriptionRefills')
              expect(data['attributes']).to have_key('failedStationList')
              expect(data['attributes']).to have_key('successfulStationList')
              expect(data['attributes']).to have_key('lastUpdatedTime')
              expect(data['attributes']).to have_key('prescriptionList')
              expect(data['attributes']).to have_key('failedPrescriptionIds')
              expect(data['attributes']).to have_key('errors')
              expect(data['attributes']).to have_key('infoMessages')
            end
          end
        end
      end

      context 'when prescription does not exist for refill' do
        it 'returns not found error' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            put '/mobile/v1/health/rx/prescriptions/refill', params: { ids: %w[nonexistent] }, headers: sis_headers

            expect(response).to have_http_status(:not_found)
            expect(response.parsed_body['errors'][0]['detail']).to include('Prescription not found')
          end
        end
      end

      context 'when no ids parameter provided' do
        it 'returns parameter required error' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            put '/mobile/v1/health/rx/prescriptions/refill', headers: sis_headers

            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end
  end
end
