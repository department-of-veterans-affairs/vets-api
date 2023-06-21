# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'

RSpec.describe 'Medical Records Integration', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  it 'responds to GET #index' do
    VCR.use_cassette('mr_client/get_a_list_of_vitals') do
      get '/my_health/v1/medical_records/vitals?patient_id=30163'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
  end
end
