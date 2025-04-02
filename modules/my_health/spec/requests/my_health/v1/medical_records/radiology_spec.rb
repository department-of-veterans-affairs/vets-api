# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'

RSpec.describe 'MyHealth::V1::MedicalRecords::Radiology', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  let(:va_patient) { true }
  let(:mhv_account_type) { 'Premium' }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)
    bb_internal_client = BBInternal::Client.new(
      session: {
        user_id: 11_375_034,
        icn: '1000000000V000000',
        patient_id: '11382904',
        expires_at: 1.hour.from_now,
        token: 'SESSION_TOKEN'
      }
    )
    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    allow(BBInternal::Client).to receive(:new).and_return(bb_internal_client)
    sign_in_as(current_user)
    VCR.insert_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                        match_requests_on: %i[method sm_user_ignoring_path_param])
  end

  after do
    VCR.eject_cassette
  end

  it 'responds to GET #index' do
    VCR.use_cassette('mr_client/bb_internal/get_radiology') do
      get '/my_health/v1/medical_records/radiology'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
  end

  context 'when the patient ID is not found for a user profile' do
    before do
      allow_any_instance_of(BBInternal::Client).to receive(:list_radiology)
        .and_raise(Common::Exceptions::ServiceError)
    end

    it 'returns a 500 response for GET #index' do
      get '/my_health/v1/medical_records/radiology'
      expect(response).to have_http_status(:internal_server_error)
    end
  end
end
