# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'

RSpec.describe 'Medical Records Integration', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  it 'responds to GET #index' do
    VCR.use_cassette('mr_client/get_a_list_of_health_conditions') do
      get '/my_health/v1/medical_records/conditions?patient_id=39254'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
  end

  it 'responds to GET #show' do
    VCR.use_cassette('mr_client/get_a_health_condition') do
      get '/my_health/v1/medical_records/conditions/39274'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
  end

  it 'responds with an error to GET #index when no patient ID is provided' do
    VCR.use_cassette('mr_client/get_a_list_of_health_conditions_error') do
      get '/my_health/v1/medical_records/conditions?patient_id='
    end

    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to include 'wrong number of arguments (given 0, expected 1)'
  end

  it 'responds with an error to GET #show when no condition ID is provided' do
    VCR.use_cassette('mr_client/get_a_health_condition_error') do
      get '/my_health/v1/medical_records/conditions'
    end

    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to include 'wrong number of arguments (given 0, expected 1)'
  end
end
