# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'

RSpec.describe 'Medical Records Integration', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '11898795' }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }

  before do
    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    sign_in_as(current_user)
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

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

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include 'Parameter value missing in request'
    end

    it 'responds with an error to GET #show when no condition ID is provided' do
      VCR.use_cassette('mr_client/get_a_health_condition_error') do
        get '/my_health/v1/medical_records/conditions'
      end

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include 'Parameter value missing in request'
    end
  end
end
