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
      VCR.use_cassette('mr_client/get_a_list_of_clinical_notes') do
        get '/my_health/v1/medical_records/clinical_notes'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
    end

    it 'responds to GET #show' do
      VCR.use_cassette('mr_client/get_a_clinical_note') do
        get '/my_health/v1/medical_records/clinical_notes/1175305'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
    end

    context 'when the patient is not found' do
      before do
        allow_any_instance_of(MedicalRecords::Client).to receive(:list_clinical_notes)
          .and_raise(MedicalRecords::PatientNotFound)
        allow_any_instance_of(MedicalRecords::Client).to receive(:get_clinical_note)
          .and_raise(MedicalRecords::PatientNotFound)
      end

      it 'returns a 202 Accepted response for GET #index' do
        get '/my_health/v1/medical_records/clinical_notes'
        expect(response).to have_http_status(:accepted)
      end

      it 'returns a 202 Accepted response for GET #show' do
        get '/my_health/v1/medical_records/clinical_notes/1175305'
        expect(response).to have_http_status(:accepted)
      end
    end
  end
end
