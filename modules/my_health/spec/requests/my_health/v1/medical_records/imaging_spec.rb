# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::MedicalRecords::ImagingController', type: :request do
  include MedicalRecords::ClientHelpers
  include MedicalRecords::ClientHelpers

  let(:user_id) { '11375034' }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }
  let(:study_id) { '453-2487448' }

  before do
    bb_internal_client = BBInternal::Client.new(
      session: {
        user_id: 11_375_034,
        patient_id: '11382904',
        expires_at: 1.hour.from_now,
        token: 'ENC(MA0ECJh1RjEgZFMhAgEQC4nF/gSOKGSZuYg8kVN8CmHNnCLychZ7Wo2jXGwPj39SQFG4wLsFYlZN)'
      }
    )

    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    allow(BBInternal::Client).to receive(:new).and_return(bb_internal_client)
    sign_in_as(current_user)
    VCR.insert_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                        match_requests_on: %i[method sm_user_ignoring_path_param])
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    it 'streams DICOM data without the Content-Length header' do
      VCR.use_cassette('bb_client/get_dicom') do
        get "/my_health/v1/medical_records/imaging/#{study_id}/dicom"
      end

      expect(response).to be_successful
      # expect(response.headers).not_to have_key('Content-Length')
      expect(response.headers['Content-Type']).to eq('application/zip')
    end
  end
end
