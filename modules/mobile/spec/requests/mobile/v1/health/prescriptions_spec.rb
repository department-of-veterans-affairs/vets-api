# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V1::Health::Rx::Prescriptions', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(icn: '9000682') }
  let(:uhd_client) { instance_double(UnifiedHealthData::Service) }
  let(:sample_uhd_prescription) do
    {
      prescription_id: '12345',
      medication_name: 'Test Medication',
      instructions: 'Take once daily',
      fill_date: '2024-01-15',
      quantity: 30,
      refills_remaining: 2,
      status: 'active',
      prescriber_name: 'Dr. Smith',
      pharmacy_name: 'VA Pharmacy',
      rx_number: 'RX12345'
    }
  end
  let(:sample_uhd_refill_response) do
    {
      status: 'success',
      refilled_prescriptions: [
        {
          prescription_id: '12345',
          status: 'refilled',
          fill_date: '2024-01-20'
        }
      ],
      failed_prescriptions: [],
      errors: []
    }
  end

  before do
    allow(UnifiedHealthData::Service).to receive(:new).and_return(uhd_client)
    allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, user).and_return(true)
    Timecop.freeze(Time.zone.parse('2024-01-15T00:00:00.000Z'))
  end

  after do
    Timecop.return
  end

  describe 'GET /mobile/v1/health/rx/prescriptions' do
    context 'when UHD service returns prescriptions' do
      before do
        allow(uhd_client).to receive(:get_prescriptions).and_return([sample_uhd_prescription])
        get '/mobile/v1/health/rx/prescriptions', headers: sis_headers
      end

      it 'returns a 200 status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns prescriptions data in the expected format' do
        data = response.parsed_body['data']
        expect(data).to be_an(Array)
        expect(data.first).to include(
          'id' => '12345',
          'type' => 'prescription',
          'attributes' => include(
            'prescriptionId' => 12345,
            'prescriptionName' => 'Test Medication',
            'instructions' => 'Take once daily',
            'fillDate' => '2024-01-15',
            'quantity' => 30,
            'refillRemaining' => 2,
            'refillStatus' => 'active',
            'prescribedDate' => nil,
            'expirationDate' => nil,
            'facilityName' => 'VA Pharmacy',
            'orderedDate' => nil,
            'prescriptionSource' => 'UHD'
          )
        )
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, user).and_return(false)
        get '/mobile/v1/health/rx/prescriptions', headers: sis_headers
      end

      it 'returns 501 Not Implemented' do
        expect(response).to have_http_status(:not_implemented)
      end

      it 'returns appropriate error message' do
        error = response.parsed_body['errors'].first
        expect(error['title']).to eq('Not Implemented')
        expect(error['detail']).to eq('Mobile v1 prescriptions endpoint requires feature flag')
      end
    end

    context 'when UHD service raises an error' do
      before do
        allow(uhd_client).to receive(:get_prescriptions).and_raise(StandardError, 'UHD service unavailable')
        get '/mobile/v1/health/rx/prescriptions', headers: sis_headers
      end

      it 'returns 502 Bad Gateway' do
        expect(response).to have_http_status(:bad_gateway)
      end

      it 'returns appropriate error message' do
        error = response.parsed_body['errors'].first
        expect(error['title']).to eq('Bad Gateway')
        expect(error['detail']).to eq('UHD service unavailable')
      end
    end

    context 'with pagination parameters' do
      before do
        allow(uhd_client).to receive(:get_prescriptions).and_return([sample_uhd_prescription])
        get '/mobile/v1/health/rx/prescriptions', 
            headers: sis_headers,
            params: { page: { number: 1, size: 10 } }
      end

      it 'returns a 200 status' do
        expect(response).to have_http_status(:ok)
      end

      it 'includes pagination metadata' do
        meta = response.parsed_body['meta']
        expect(meta).to include('pagination')
      end
    end
  end

  describe 'PUT /mobile/v1/health/rx/prescriptions/refill' do
    context 'when UHD service successfully refills prescriptions' do
      before do
        allow(uhd_client).to receive(:refill_prescription).and_return(sample_uhd_refill_response)
        put '/mobile/v1/health/rx/prescriptions/refill', 
            params: { ids: ['12345'] }, 
            headers: sis_headers
      end

      it 'returns a 200 status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns refill data in the expected format' do
        data = response.parsed_body['data']
        expect(data).to include(
          'type' => 'prescriptionsRefills',
          'attributes' => include(
            'failedStationList' => '',
            'successfulStationList' => '',
            'lastUpdatedTime' => be_present,
            'prescriptionList' => nil,
            'failedPrescriptionIds' => [],
            'errors' => [],
            'infoMessages' => []
          )
        )
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, user).and_return(false)
        put '/mobile/v1/health/rx/prescriptions/refill', 
            params: { ids: ['12345'] }, 
            headers: sis_headers
      end

      it 'returns 501 Not Implemented' do
        expect(response).to have_http_status(:not_implemented)
      end
    end

    context 'when UHD service returns errors' do
      let(:uhd_error_response) do
        {
          status: 'error',
          refilled_prescriptions: [],
          failed_prescriptions: [
            {
              prescription_id: '12345',
              error_code: 139,
              error_message: 'Prescription not refillable'
            }
          ],
          errors: ['Prescription not refillable for id: 12345']
        }
      end

      before do
        allow(uhd_client).to receive(:refill_prescription).and_return(uhd_error_response)
        put '/mobile/v1/health/rx/prescriptions/refill', 
            params: { ids: ['12345'] }, 
            headers: sis_headers
      end

      it 'returns a 200 status with error details' do
        expect(response).to have_http_status(:ok)
        data = response.parsed_body['data']
        expect(data['attributes']['failedPrescriptionIds']).to eq(['12345'])
        expect(data['attributes']['errors']).not_to be_empty
      end
    end

    context 'with invalid parameters' do
      before do
        put '/mobile/v1/health/rx/prescriptions/refill', 
            params: { ids: '12345' }, # Should be array
            headers: sis_headers
      end

      it 'returns 400 Bad Request' do
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'GET /mobile/v1/health/rx/prescriptions/:id/tracking' do
    context 'when endpoint is called' do
      before do
        get '/mobile/v1/health/rx/prescriptions/12345/tracking', headers: sis_headers
      end

      it 'returns 501 Not Implemented' do
        expect(response).to have_http_status(:not_implemented)
      end

      it 'returns appropriate error message' do
        error = response.parsed_body['errors'].first
        expect(error['title']).to eq('Not Implemented')
        expect(error['detail']).to eq('Tracking is not yet implemented for mobile v1 prescriptions')
      end
    end
  end
end
