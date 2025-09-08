# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V1::PrescriptionsController, type: :controller do
  let(:user) { create(:user, :loa3, :mhv_account) }
  let(:uhd_service) { instance_double(UnifiedHealthData::Service) }
  let(:sample_uhd_prescription) do
    UnifiedHealthData::Prescription.new(
      id: '12345',
      type: 'prescription',
      attributes: UnifiedHealthData::PrescriptionAttributes.new(
        prescription_name: 'METFORMIN HCL 500MG TAB',
        refill_status: 'active',
        refill_submit_date: '2024-01-15',
        refill_date: '2024-01-20',
        refill_remaining: 3,
        facility_name: 'CHEYENNE VA MEDICAL CENTER',
        ordered_date: '2023-12-01',
        quantity: '90',
        expiration_date: '2024-12-01',
        prescription_number: 'RX12345',
        dispensed_date: '2023-12-05',
        station_number: '442',
        is_refillable: true,
        is_trackable: true,
        instructions: 'Take one tablet by mouth twice daily',
        facility_phone_number: '307-778-7550',
        data_source_system: 'vista'
      )
    )
  end

  before do
    sign_in_as(user)
    allow(UnifiedHealthData::Service).to receive(:new).with(user).and_return(uhd_service)
  end

  describe 'GET #index' do
    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, user).and_return(true)
        allow(uhd_service).to receive(:get_prescriptions).and_return([sample_uhd_prescription])
      end

      it 'returns prescriptions from UHD service' do
        get :index

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']).to be_an(Array)
        expect(json_response['data'].first['attributes']['prescription_name']).to eq('METFORMIN HCL 500MG TAB')
        expect(json_response['data'].first['attributes']['data_source_system']).to eq('vista')
      end

      it 'includes UHD metadata' do
        get :index

        json_response = JSON.parse(response.body)
        expect(json_response['meta']['data_source']).to eq('unified_health_data')
        expect(json_response['meta']['pilot_version']).to eq('v1_uhd')
        expect(json_response['meta']['vista_count']).to eq(1)
        expect(json_response['meta']['oracle_health_count']).to eq(0)
      end

      it 'logs pilot usage' do
        expect(Rails.logger).to receive(:info).with(
          hash_including(
            message: 'Mobile v1 prescriptions accessed via UHD',
            user_icn: user.icn
          )
        )

        get :index
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, user).and_return(false)
      end

      it 'returns forbidden error' do
        expect { get :index }.to raise_error(Common::Exceptions::Forbidden)
      end
    end
  end

  describe 'PUT #refill' do
    let(:uhd_refill_response) do
      {
        success: [{ id: 123, status: 'submitted' }],
        failed: [{ id: 456, error: 'Not refillable' }]
      }
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, user).and_return(true)
        allow(uhd_service).to receive(:refill_prescription).with([123, 456]).and_return(uhd_refill_response)
      end

      it 'submits refill via UHD service' do
        put :refill, params: { ids: [123, 456] }

        expect(response).to have_http_status(:ok)
        expect(uhd_service).to have_received(:refill_prescription).with([123, 456])
      end

      it 'returns transformed refill response' do
        put :refill, params: { ids: [123, 456] }

        json_response = JSON.parse(response.body)
        expect(json_response['data']['type']).to eq('PrescriptionRefills')
        expect(json_response['data']['attributes']).to include('prescription_list')
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, user).and_return(false)
      end

      it 'returns forbidden error' do
        expect { put :refill, params: { ids: [123, 456] } }.to raise_error(Common::Exceptions::Forbidden)
      end
    end
  end

  describe 'GET #tracking' do
    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, user).and_return(true)
      end

      it 'returns not implemented status' do
        get :tracking, params: { id: 123 }

        expect(response).to have_http_status(:not_implemented)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['code']).to eq('not_implemented')
      end
    end
  end
end