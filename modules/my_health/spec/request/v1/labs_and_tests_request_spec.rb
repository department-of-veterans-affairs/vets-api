# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'

RSpec.describe 'Medical Records Integration', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  it 'responds to GET #index' do
    VCR.use_cassette('mr_client/get_a_list_of_labs_and_tests') do
      get '/my_health/v1/medical_records/labs_and_tests?patient_id=258974'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
  end

  it 'responds to GET #show' do
    VCR.use_cassette('mr_client/get_a_single_lab_or_test') do
      get '/my_health/v1/medical_records/labs_and_tests/40766'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
  end
end
