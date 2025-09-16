# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V1::Health::Prescriptions', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(icn: '1000123456V123456') }
  let(:va_patient) { true }
  let(:current_user) { user }

  before do
    allow_any_instance_of(User).to receive(:va_patient?).and_return(va_patient)
    sign_in_as(user)
    allow(Flipper).to receive(:enabled?).with(:mobile_prescriptions_v1, user).and_return(true)
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
        allow(Flipper).to receive(:enabled?).with(:mobile_prescriptions_v1, user).and_return(false)
      end

      it 'returns forbidden error' do
        get '/mobile/v1/health/rx/prescriptions', headers: sis_headers

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']['code']).to eq('FEATURE_NOT_AVAILABLE')
      end
    end

    context 'with feature flag enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mobile_prescriptions_v1, anything).and_return(true)
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

        it 'caps per_page at 50 for mobile performance' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            get '/mobile/v1/health/rx/prescriptions', params: { per_page: 100 }, headers: sis_headers

            expect(response).to have_http_status(:ok)
            meta = response.parsed_body['meta']['pagination']
            expect(meta['perPage']).to eq(50)
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

  describe 'GET /mobile/v1/health/rx/prescriptions/:id' do
    context 'with feature flag enabled' do
      context 'when prescription exists' do
        it 'returns the specific prescription' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            # The cassette should have a prescription with this ID
            get '/mobile/v1/health/rx/prescriptions/123', headers: sis_headers

            expect(response).to have_http_status(:ok)
            expect(response.parsed_body).to have_key('data')
          end
        end
      end

      context 'when prescription does not exist' do
        it 'returns not found error' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            get '/mobile/v1/health/rx/prescriptions/nonexistent', headers: sis_headers

            expect(response).to have_http_status(:not_found)
            expect(response.parsed_body['error']['detail']).to eq('Prescription not found')
          end
        end
      end
    end
  end

  describe 'POST /mobile/v1/health/rx/prescriptions/:id/refill' do
    context 'with feature flag enabled' do
      context 'when refill is successful' do
        it 'returns success response' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            VCR.use_cassette('unified_health_data/refill_prescription_success') do
              post '/mobile/v1/health/rx/prescriptions/123/refill', headers: sis_headers

              expect(response).to have_http_status(:ok)
              expect(response.parsed_body['data']).to have_key('prescription_id')
              expect(response.parsed_body['data']).to have_key('refill_status')
            end
          end
        end
      end

      context 'when prescription does not exist for refill' do
        it 'returns not found error' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            post '/mobile/v1/health/rx/prescriptions/nonexistent/refill', headers: sis_headers

            expect(response).to have_http_status(:not_found)
            expect(response.parsed_body['error']['detail']).to eq('Prescription not found')
          end
        end
      end
    end
  end
end