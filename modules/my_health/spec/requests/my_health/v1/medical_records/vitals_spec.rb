# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'
require 'support/shared_examples_for_mr'

RSpec.describe 'MyHealth::V1::MedicalRecords::Vitals', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '11898795' }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }

  before do
    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    allow(BBInternal::Client).to receive(:new).and_return(authenticated_client)
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_new_eligibility_check).and_return(false)
    sign_in_as(current_user)
  end

  include_examples 'medical records new eligibility check',
                   '/my_health/v1/medical_records/vitals',
                   'mr_client/get_a_list_of_vitals'

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    before { get '/my_health/v1/medical_records/vitals' }

    include_examples 'for user account level', message: 'You do not have access to medical records'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to medical records'
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    before { get '/my_health/v1/medical_records/vitals' }

    include_examples 'for user account level', message: 'You do not have access to medical records'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to medical records'
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    context 'not a va patient' do
      before { get '/my_health/v1/medical_records/vitals' }

      let(:va_patient) { false }
      let(:current_user) do
        build(:user, :mhv, :no_vha_facilities, va_patient:, mhv_account_type:)
      end

      include_examples 'for non va patient user', authorized: false,
                                                  message: 'You do not have access to medical records'
    end

    it 'responds to GET #index' do
      allow(UniqueUserEvents).to receive(:log_events)
      VCR.use_cassette('mr_client/get_a_list_of_vitals') do
        get '/my_health/v1/medical_records/vitals'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      # Verify event logging was called
      expect(UniqueUserEvents).to have_received(:log_events).with(
        user: anything,
        event_names: [
          UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
          UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_VITALS_ACCESSED
        ]
      )
    end

    context 'when the patient is not found' do
      before do
        allow_any_instance_of(MedicalRecords::Client).to receive(:list_vitals)
          .and_return(:patient_not_found)
      end

      it 'returns a 202 Accepted response for GET #index' do
        get '/my_health/v1/medical_records/vitals'
        expect(response).to have_http_status(:accepted)
      end
    end
  end

  context 'Premium User when use_oh_data_path is true' do
    let(:mhv_account_type) { 'Premium' }
    let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:, icn: '23000219') }

    before do
      sign_in_as(current_user)

      # The "accelerated delivery" flippers now control whether UHD is used,
      # so we need to disable them to test the Lighthouse OH data path.
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled,
                                                instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_vital_signs_enabled,
                                                instance_of(User)).and_return(false)

      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_new_eligibility_check).and_return(false)
    end

    it 'responds to GET #index' do
      VCR.use_cassette('mr_client/get_a_list_of_vitals_oh_data_path', match_requests_on: %i[method]) do
        get '/my_health/v1/medical_records/vitals?use_oh_data_path=1'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      body = JSON.parse(response.body)

      expect(body['entry']).to be_an(Array)
      expect(body['entry'].size).to be 6

      # Verify that items are sorted by effectiveDateTime in descending order
      expect(body['entry'][0]['resource']['effectiveDateTime']).to eq('2019-11-30T08:34:29Z')
      expect(body['entry'][2]['resource']['effectiveDateTime']).to eq('2019-11-30T08:24:29Z')
      expect(body['entry'][5]['resource']['effectiveDateTime']).to eq('2019-11-30T07:28:29Z')

      item = body['entry'][2]
      expect(item['resource']['resourceType']).to eq('Observation')
      expect(item['resource']['code']['text']).to eq('Blood Pressure')
    end
  end
end
