# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::MedicalRecords::Allergies', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '11898795' }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)
    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    allow(BBInternal::Client).to receive(:new).and_return(authenticated_client)
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

    before do
      VCR.insert_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                          match_requests_on: %i[method sm_user_ignoring_path_param])
    end

    after do
      VCR.eject_cassette
    end

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
      VCR.use_cassette('mr_client/get_a_list_of_allergies') do
        get '/my_health/v1/medical_records/allergies'
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

    context 'when the patient is not found' do
      before do
        allow_any_instance_of(MedicalRecords::Client).to receive(:list_allergies)
          .and_raise(MedicalRecords::PatientNotFound)
        allow_any_instance_of(MedicalRecords::Client).to receive(:get_allergy)
          .and_raise(MedicalRecords::PatientNotFound)
      end

      it 'returns a 202 Accepted response for GET #index' do
        get '/my_health/v1/medical_records/allergies'
        expect(response).to have_http_status(:accepted)
      end

      it 'returns a 202 Accepted response for GET #show' do
        get '/my_health/v1/medical_records/allergies/30242'
        expect(response).to have_http_status(:accepted)
      end
    end
  end

  context 'Premium user when use_oh_data_path is true' do
    let(:mhv_account_type) { 'Premium' }
    let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:, icn: '23000219') }

    before do
      sign_in_as(current_user)

      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled,
                                                instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_new_eligibility_check).and_return(false)
    end

    it 'responds to GET #index' do
      VCR.use_cassette('mr_client/get_a_list_of_allergies_oh_data_path') do
        get '/my_health/v1/medical_records/allergies?use_oh_data_path=1'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      body = JSON.parse(response.body)

      expect(body['entry']).to be_an(Array)
      expect(body['entry'].size).to be 2

      # Verify that items are sorted by recordedDate in descending order
      expect(body['entry'][0]['resource']['recordedDate']).to eq('1967-05-28T12:25:29Z')
      expect(body['entry'][1]['resource']['recordedDate']).to eq('1967-05-28T12:24:29Z')

      item = body['entry'][1]
      expect(item['resource']['resourceType']).to eq('AllergyIntolerance')
      expect(item['resource']['category'][0]).to eq('food')
    end

    it 'responds to GET #show' do
      allergy_id = '4-6Z8D6dAzABlkPZA'

      VCR.use_cassette('mr_client/get_an_allergy_oh_data_path') do
        get "/my_health/v1/medical_records/allergies/#{allergy_id}?use_oh_data_path=1"
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      body = JSON.parse(response.body)
      expect(body['resourceType']).to eq('AllergyIntolerance')
      expect(body['id']).to eq(allergy_id)
      expect(body['category'][0]).to eq('food')
    end
  end
end
