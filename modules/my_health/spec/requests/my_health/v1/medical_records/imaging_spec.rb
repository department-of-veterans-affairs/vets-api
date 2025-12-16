# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::MedicalRecords::ImagingController', type: :request do
  include MedicalRecords::ClientHelpers

  let(:user_id) { '11375034' }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:, icn:) }

  before do
    bb_internal_client = BBInternal::Client.new(
      session: {
        user_id: 11_375_034,
        patient_id: '11382904',
        expires_at: 1.hour.from_now,
        token: 'SESSION_TOKEN'
      }
    )

    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    allow(BBInternal::Client).to receive(:new).and_return(bb_internal_client)
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_new_eligibility_check).and_return(false)
    sign_in_as(current_user)
  end

  RSpec.shared_context 'redis setup' do
    let(:redis) { instance_double(Redis::Namespace) }
    # let(:study_id) { '453-2487450' }
    let(:uuid) { 'c9396040-23b7-44bc-a505-9127ed968b0d' }
    let(:cached_data) do
      {
        uuid => study_id
      }.to_json
    end
    let(:namespace) { REDIS_CONFIG[:bb_internal_store][:namespace] }
    let(:study_data_key) { 'study_data-11382904' }

    before do
      allow(Redis::Namespace).to receive(:new).with(namespace, redis: $redis).and_return(redis)
      allow(redis).to receive(:get).with(study_data_key).and_return(cached_data)
    end
  end

  context 'Premium User' do
    include_context 'redis setup'

    let(:mhv_account_type) { 'Premium' }

    describe 'GET #request_download' do
      let(:icn) { '1012740022V620959' }
      let(:study_id) { '453-2487450' }

      it 'requests study download' do
        VCR.use_cassette('mr_client/bb_internal/request_study') do
          get "/my_health/v1/medical_records/imaging/#{uuid}/request"
        end

        expect(response).to be_successful
        body = JSON.parse(response.body)
        expect(body).to be_a(Hash)
        expect(body['status']).to eq('COMPLETE')
      end
    end

    describe 'GET #dicom' do
      let(:icn) { '1000123456V123456' }
      let(:study_id) { '453-2487448' }

      it 'streams DICOM data' do
        VCR.use_cassette('bb_client/get_dicom') do
          get "/my_health/v1/medical_records/imaging/#{uuid}/dicom"
        end

        expect(response).to be_successful
        expect(response.headers['Content-Type']).to eq('application/zip')
      end
    end
  end
end
