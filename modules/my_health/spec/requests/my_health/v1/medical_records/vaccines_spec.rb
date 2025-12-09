# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'
require 'support/shared_examples_for_mr'

RSpec.describe 'MyHealth::V1::MedicalRecords::Vaccines', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '11898795' }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_support_new_model_vaccine).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_new_eligibility_check).and_return(false)
    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    allow(BBInternal::Client).to receive(:new).and_return(authenticated_client)
    sign_in_as(current_user)
  end

  include_examples 'medical records new eligibility check',
                   '/my_health/v1/medical_records/vaccines',
                   'mr_client/get_a_list_of_vaccines'

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    before { get '/my_health/v1/medical_records/vaccines' }

    include_examples 'for user account level', message: 'You do not have access to medical records'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to medical records'
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    before { get '/my_health/v1/medical_records/vaccines' }

    include_examples 'for user account level', message: 'You do not have access to medical records'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to medical records'
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    context 'not a va patient' do
      before { get '/my_health/v1/medical_records/vaccines' }

      let(:va_patient) { false }
      let(:current_user) do
        build(:user, :mhv, :no_vha_facilities, va_patient:, mhv_account_type:)
      end

      include_examples 'for non va patient user', authorized: false,
                                                  message: 'You do not have access to medical records'
    end

    it 'responds to GET #index' do
      VCR.use_cassette('mr_client/get_a_list_of_vaccines') do
        get '/my_health/v1/medical_records/vaccines'
      end

      body = JSON.parse(response.body)
      expect(response).to be_successful
      expect(body['entry']).to be_a(Array)
      expect(body['entry'][0]['resource']['resourceType']).to eq('Immunization')
      expect(body['entry'][0]['resource']['vaccineCode']['coding'][0]['display']).to eq('SARSCOV2 VAC 5X1010VP/.5MLIM')
    end

    it 'responds to GET #show' do
      VCR.use_cassette('mr_client/get_a_vaccine') do
        get '/my_health/v1/medical_records/vaccines/2954'
      end

      expect(response).to be_successful
      body = JSON.parse(response.body)
      expect(body['resourceType']).to eq('Immunization')
      expect(body['vaccineCode']['coding'][0]['display']).to eq('SMALLPOX&MONKEYPOX VAC 0.5ML')
    end

    context 'when the patient is not found' do
      before do
        allow_any_instance_of(MedicalRecords::Client).to receive(:list_vaccines)
          .and_return(:patient_not_found)
        allow_any_instance_of(MedicalRecords::Client).to receive(:get_vaccine)
          .and_return(:patient_not_found)
      end

      it 'returns a 202 Accepted response for GET #index' do
        get '/my_health/v1/medical_records/vaccines'
        expect(response).to have_http_status(:accepted)
      end

      it 'returns a 202 Accepted response for GET #show' do
        get '/my_health/v1/medical_records/vaccines/2954'
        expect(response).to have_http_status(:accepted)
      end
    end
  end
end
