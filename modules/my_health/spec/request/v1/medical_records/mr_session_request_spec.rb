# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'

RSpec.describe 'Medical Records Session', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  let(:va_patient) { true }
  let(:mhv_account_type) { 'Premium' }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }

  before do
    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    sign_in_as(current_user)
  end

  it 'responds to POST #create' do
    post '/my_health/v1/medical_records/session'
    expect(response).to be_successful
    expect(response).to have_http_status(:no_content)
    expect(response.body).to be_empty
  end
end
