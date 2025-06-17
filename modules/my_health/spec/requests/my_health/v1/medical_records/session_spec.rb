# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'medical_records/phr_mgr/client'

RSpec.describe 'MyHealth::V1::MedicalRecords::Session', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  let(:va_patient) { true }
  let(:mhv_account_type) { 'Premium' }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)
    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    allow(BBInternal::Client).to receive(:new).and_return(authenticated_client)
    allow(PHRMgr::Client).to receive(:new).and_return(PHRMgr::Client.new(12_345))
    sign_in_as(current_user)
    VCR.insert_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                        match_requests_on: %i[method sm_user_ignoring_path_param])
  end

  after do
    VCR.eject_cassette
  end

  it 'responds to POST #create' do
    post '/my_health/v1/medical_records/session'
    expect(response).to be_successful
    expect(response).to have_http_status(:no_content)
    expect(response.body).to be_empty
  end

  it 'responds to GET #status' do
    VCR.use_cassette('mr_client/get_phr_status') do
      get '/my_health/v1/medical_records/session/status'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
  end
end
