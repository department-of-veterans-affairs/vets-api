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
    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    allow(BBInternal::Client).to receive(:new).and_return(authenticated_client)
    allow(PHRMgr::Client).to receive(:new).and_return(PHRMgr::Client.new(12_345))
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_new_eligibility_check).and_return(false)
    sign_in_as(current_user)
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
