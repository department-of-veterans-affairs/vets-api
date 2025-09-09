# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe 'Mobile::V1::Health::Prescriptions', type: :request do
  include JsonSchemaMatchers

  let!(:user) { FactoryBot.create(:user, :vaos) }
  let(:va_patient) { true }
  let(:current_user) { user }

  before do
    allow_any_instance_of(User).to receive(:va_patient?).and_return(va_patient)
    sign_in_as(user)
  end

  describe 'GET /mobile/v1/health/rx/prescriptions' do
    context 'with feature flag enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mobile_prescriptions_v1, current_user).and_return(true)
      end

      context 'when UHD service returns prescriptions successfully' do
        let(:mock_prescriptions) do
          [
            UnifiedHealthData::Models::Prescription.new(
              prescription_id: '123',
              prescription_name: 'Test Medication',
              dispense_date: '2024-01-15',
              quantity: 30,
              refills_remaining: 2,
              facility_name: 'VAMC Test',
              prescribed_date: '2024-01-01',
              ndc_number: '12345-678-90',
              prescription_source: 'va',
              refill_status: 'active',
              tracking_info: [
                { tracking_number: 'TRK123', shipper: 'UPS', delivery_service: 'Ground' }
              ]
            )
          ]
        end

        before do
          allow(UnifiedHealthData::Service).to receive(:get_prescriptions).and_return(mock_prescriptions)
        end

        it 'returns prescriptions with mobile-specific metadata' do
          get '/mobile/v1/health/rx/prescriptions'

          expect(response).to have_http_status(:ok)
          json = response.parsed_body

          expect(json['data']).to be_an(Array)
          expect(json['meta']).to include('pagination')
          expect(json['meta']).to include('prescriptionStatusCount')
          expect(json['meta']).to include('hasNonVaMeds')
        end

        it 'includes UHD-specific fields in serialized data' do
          get '/mobile/v1/health/rx/prescriptions'

          json = response.parsed_body
          prescription = json['data'].first

          expect(prescription['attributes']).to include('prescription_source')
          expect(prescription['attributes']).to include('tracking_info')
          expect(prescription['attributes']).to include('ndc_number')
          expect(prescription['attributes']).to include('prescribed_date')
        end

        it 'handles pagination parameters correctly' do
          get '/mobile/v1/health/rx/prescriptions', params: { page: 2, per_page: 10 }

          expect(UnifiedHealthData::Service).to have_received(:get_prescriptions).with(
            user: current_user,
            page: 2,
            per_page: 10,
            refill_status: nil,
            sort: '-dispensed_date'
          )
        end

        it 'caps per_page at 50 for mobile performance' do
          get '/mobile/v1/health/rx/prescriptions', params: { per_page: 100 }

          expect(UnifiedHealthData::Service).to have_received(:get_prescriptions).with(
            user: current_user,
            page: 1,
            per_page: 50,
            refill_status: nil,
            sort: '-dispensed_date'
          )
        end

        it 'handles refill_status filter' do
          get '/mobile/v1/health/rx/prescriptions', params: { refill_status: 'active' }

          expect(UnifiedHealthData::Service).to have_received(:get_prescriptions).with(
            user: current_user,
            page: 1,
            per_page: 20,
            refill_status: 'active',
            sort: '-dispensed_date'
          )
        end

        it 'handles sort parameter' do
          get '/mobile/v1/health/rx/prescriptions', params: { sort: 'prescription_name' }

          expect(UnifiedHealthData::Service).to have_received(:get_prescriptions).with(
            user: current_user,
            page: 1,
            per_page: 20,
            refill_status: nil,
            sort: 'prescription_name'
          )
        end

        it 'generates correct prescription status counts' do
          mock_prescriptions << UnifiedHealthData::Models::Prescription.new(
            prescription_id: '124',
            prescription_name: 'Test Med 2',
            refill_status: 'expired'
          )
          allow(UnifiedHealthData::Service).to receive(:get_prescriptions).and_return(mock_prescriptions)

          get '/mobile/v1/health/rx/prescriptions'

          json = response.parsed_body
          status_counts = json['meta']['prescriptionStatusCount']

          expect(status_counts['active']).to eq(1)
          expect(status_counts['expired']).to eq(1)
        end

        it 'detects non-VA medications correctly' do
          mock_prescriptions.first.prescription_source = 'community_care'
          allow(UnifiedHealthData::Service).to receive(:get_prescriptions).and_return(mock_prescriptions)

          get '/mobile/v1/health/rx/prescriptions'

          json = response.parsed_body
          expect(json['meta']['hasNonVaMeds']).to be true
        end
      end

      context 'when UHD service raises an error' do
        before do
          allow(UnifiedHealthData::Service).to receive(:get_prescriptions).and_raise(StandardError, 'Service error')
        end

        it 'returns service unavailable error with standard format' do
          get '/mobile/v1/health/rx/prescriptions'

          expect(response).to have_http_status(:service_unavailable)
          json = response.parsed_body

          expect(json['error']).to include(
            'code' => 'PRESCRIPTION_SERVICE_ERROR',
            'message' => 'Unable to retrieve prescriptions at this time'
          )
        end
      end
    end

    context 'with feature flag disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mobile_prescriptions_v1, current_user).and_return(false)
      end

      it 'returns forbidden error' do
        get '/mobile/v1/health/rx/prescriptions'

        expect(response).to have_http_status(:forbidden)
        json = response.parsed_body

        expect(json['error']).to include(
          'code' => 'FEATURE_NOT_AVAILABLE',
          'message' => 'This feature is not currently available'
        )
      end
    end

    context 'when user is not authenticated' do
      before do
        sign_out
      end

      it 'returns unauthorized' do
        get '/mobile/v1/health/rx/prescriptions'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /mobile/v1/health/rx/prescriptions/:id' do
    let(:prescription_id) { '123' }

    context 'with feature flag enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mobile_prescriptions_v1, current_user).and_return(true)
      end

      context 'when prescription exists' do
        let(:mock_prescription) do
          UnifiedHealthData::Models::Prescription.new(
            prescription_id: prescription_id,
            prescription_name: 'Test Medication',
            dispense_date: '2024-01-15'
          )
        end

        before do
          allow(UnifiedHealthData::Service).to receive(:get_prescription).and_return(mock_prescription)
        end

        it 'returns the specific prescription' do
          get "/mobile/v1/health/rx/prescriptions/#{prescription_id}"

          expect(response).to have_http_status(:ok)
          expect(UnifiedHealthData::Service).to have_received(:get_prescription).with(
            user: current_user,
            prescription_id: prescription_id
          )
        end
      end

      context 'when prescription does not exist' do
        before do
          allow(UnifiedHealthData::Service).to receive(:get_prescription).and_return(nil)
        end

        it 'returns not found error' do
          get "/mobile/v1/health/rx/prescriptions/#{prescription_id}"

          expect(response).to have_http_status(:not_found)
          json = response.parsed_body

          expect(json['error']).to include(
            'code' => 'PRESCRIPTION_NOT_FOUND',
            'message' => 'Prescription not found'
          )
        end
      end

      context 'when UHD service raises an error' do
        before do
          allow(UnifiedHealthData::Service).to receive(:get_prescription).and_raise(StandardError, 'Service error')
        end

        it 'returns service unavailable error' do
          get "/mobile/v1/health/rx/prescriptions/#{prescription_id}"

          expect(response).to have_http_status(:service_unavailable)
          json = response.parsed_body

          expect(json['error']).to include(
            'code' => 'PRESCRIPTION_SERVICE_ERROR',
            'message' => 'Unable to retrieve prescription details at this time'
          )
        end
      end
    end
  end

  describe 'POST /mobile/v1/health/rx/prescriptions/:id/refill' do
    let(:prescription_id) { '123' }

    context 'with feature flag enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mobile_prescriptions_v1, current_user).and_return(true)
      end

      context 'when refill is successful' do
        let(:refill_result) do
          {
            success: true,
            refill_status: 'submitted',
            refill_date: '2024-01-20'
          }
        end

        before do
          allow(UnifiedHealthData::Service).to receive(:refill_prescription).and_return(refill_result)
        end

        it 'returns success response' do
          post "/mobile/v1/health/rx/prescriptions/#{prescription_id}/refill"

          expect(response).to have_http_status(:ok)
          json = response.parsed_body

          expect(json['data']).to include(
            'prescription_id' => prescription_id,
            'refill_status' => 'submitted',
            'refill_date' => '2024-01-20'
          )
        end
      end

      context 'when refill fails' do
        let(:refill_result) do
          {
            success: false,
            error: 'Prescription not eligible for refill'
          }
        end

        before do
          allow(UnifiedHealthData::Service).to receive(:refill_prescription).and_return(refill_result)
        end

        it 'returns unprocessable entity error' do
          post "/mobile/v1/health/rx/prescriptions/#{prescription_id}/refill"

          expect(response).to have_http_status(:unprocessable_entity)
          json = response.parsed_body

          expect(json['error']).to include(
            'code' => 'REFILL_FAILED',
            'message' => 'Prescription not eligible for refill'
          )
        end
      end

      context 'when UHD service raises an error' do
        before do
          allow(UnifiedHealthData::Service).to receive(:refill_prescription).and_raise(StandardError, 'Service error')
        end

        it 'returns service unavailable error' do
          post "/mobile/v1/health/rx/prescriptions/#{prescription_id}/refill"

          expect(response).to have_http_status(:service_unavailable)
          json = response.parsed_body

          expect(json['error']).to include(
            'code' => 'REFILL_SERVICE_ERROR',
            'message' => 'Unable to process refill request at this time'
          )
        end
      end
    end
  end
end
