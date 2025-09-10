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

  context 'Premium User for DICOM streaming test' do
    let(:mhv_account_type) { 'Premium' }
    let(:study_id) { '453-2487448' }

    before do
      bb_internal_client = BBInternal::Client.new(
        session: {
          user_id: 11_375_034,
          icn: '1000000000V000000',
          patient_id: '11382904',
          expires_at: 1.hour.from_now,
          token: 'SESSION_TOKEN'
        }
      )

      allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
      allow(BBInternal::Client).to receive(:new).and_return(bb_internal_client)
      sign_in_as(current_user)
      VCR.insert_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                          match_requests_on: %i[method sm_user_ignoring_path_param])
    end

    after { VCR.eject_cassette }

    it 'streams DICOM data' do
      VCR.use_cassette('bb_client/get_dicom') do
        get "/my_health/v1/medical_records/imaging/#{study_id}/dicom"
      end

      expect(response).to be_successful
      expect(response.headers['Content-Type']).to eq('application/zip')
    end
  end

  context 'imaging endpoints' do
    let(:study_id) { '453-2487450' }
    let(:mhv_account_type) { 'Premium' }

    let(:va_patient) { true }
    let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }

    before do
      bb_internal_client = BBInternal::Client.new(session: { user_id: '11375034',
                                                             icn: '1012740022V620959',
                                                             patient_id: '11382904',
                                                             expires_at: 1.hour.from_now,
                                                             token: 'SESSION_TOKEN' })

      allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
      allow(BBInternal::Client).to receive(:new).and_return(bb_internal_client)
      sign_in_as(current_user)
      VCR.insert_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                          match_requests_on: %i[method sm_user_ignoring_path_param])
    end

    after { VCR.eject_cassette }

    it 'gets the list of imaging studies #index' do
      VCR.use_cassette 'mr_client/bb_internal/get_imaging_studies' do
        get '/my_health/v1/medical_records/imaging'
      end
      expect(response).to be_successful
      studies = JSON.parse(response.body)
      expect(studies).to be_an(Array)
      expect(studies.first).to have_key('studyIdUrn')
      expect(studies.first['studyIdUrn']).to eq('451-72913365')
    end

    it 'gets the status of all study jobs' do
      VCR.use_cassette 'mr_client/bb_internal/study_status' do
        get '/my_health/v1/medical_records/imaging/status'
      end
      expect(response).to be_successful
      study_job_list = JSON.parse(response.body)

      expect(study_job_list).to be_an(Array)
      expect(study_job_list).not_to be_empty

      first_study_job = study_job_list.first
      expect(first_study_job).to be_a(Hash)

      expect(first_study_job).to have_key('status')
      expect(first_study_job['status']).to be_a(String)
      expect(first_study_job).to have_key('studyIdUrn')
      expect(first_study_job['studyIdUrn']).to be_a(String)

      expect(first_study_job['studyIdUrn']).to eq(study_id)
    end

    it 'requests a study by study_id #request_download' do
      VCR.use_cassette 'mr_client/bb_internal/request_study' do
        get "/my_health/v1/medical_records/imaging/#{study_id}/request"
      end
      expect(response).to be_successful
      result = JSON.parse(response.body)
      expect(result).to be_a(Hash)
      expect(result).to have_key('status')
      expect(result).to have_key('studyIdUrn')

      expect(result['studyIdUrn']).to eq(study_id)
    end

    it 'lists the images for a given study #images' do
      VCR.use_cassette 'mr_client/bb_internal/list_images' do
        get "/my_health/v1/medical_records/imaging/#{study_id}/images"
      end

      expect(response).to be_successful
      images = JSON.parse(response.body)
      expect(images).to be_an(Array)
      expect(images.first).to be_a(String)
    end
  end
end
