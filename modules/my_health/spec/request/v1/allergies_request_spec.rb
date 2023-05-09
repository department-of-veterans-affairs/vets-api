# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'

RSpec.describe 'Medical Records Integration', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  it 'responds to GET #index' do
    VCR.use_cassette('mr_client/get_a_list_of_allergies') do
      get '/my_health/v1/medical_records/allergies?patient_id=30163'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
  end

  it 'responds to GET #show' do
    VCR.use_cassette('mr_client/get_an_allergy') do
      get '/my_health/v1/medical_records/allergies/30242'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
  end
end
