# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'support/shared_examples_for_mhv'

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

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    before { get '/my_health/v1/medical_records/allergies' }

    include_examples 'for user account level', message: 'You do not have access to medical records'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to medical records'
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    before { get '/my_health/v1/medical_records/allergies' }

    include_examples 'for user account level', message: 'You do not have access to medical records'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to medical records'
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    context 'not a va patient' do
      before { get '/my_health/v1/medical_records/allergies' }

      let(:va_patient) { false }
      let(:current_user) do
        build(:user, :mhv, :no_vha_facilities, va_patient:, mhv_account_type:)
      end

      include_examples 'for non va patient user', authorized: false,
                                                  message: 'You do not have access to medical records'
    end

    it 'responds to GET #index' do
      VCR.use_cassette('mr_client/get_a_list_of_health_conditions') do
        get '/my_health/v1/medical_records/conditions'
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

    # TODO: These aren't great error-condition tests because they will eventually be valid API calls.
    # Instead, when we get real data from MHV, update these to record actual error cases. For now I
    # have commented these out.

    # it 'responds with an error to GET #index when no patient ID is provided' do
    #   VCR.use_cassette('mr_client/get_a_list_of_health_conditions_error') do
    #     get '/my_health/v1/medical_records/conditions?patient_id='
    #   end

    #   expect(response).to have_http_status(:bad_request)
    #   expect(response.body).to include 'Parameter value missing in request'
    # end

    # it 'responds with an error to GET #show when no condition ID is provided' do
    #   VCR.use_cassette('mr_client/get_a_health_condition_error') do
    #     get '/my_health/v1/medical_records/conditions'
    #   end

    #   expect(response).to have_http_status(:bad_request)
    #   expect(response.body).to include 'Parameter value missing in request'
    # end
  end
end
