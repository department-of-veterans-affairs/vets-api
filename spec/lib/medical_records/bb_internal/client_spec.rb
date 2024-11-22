# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/bb_internal/client'
require 'stringio'

describe BBInternal::Client do
  before(:all) do
    # The "get_patient" cassette also contains the session auth call.
    VCR.use_cassette 'mr_client/bb_internal/get_patient' do
      @client ||= begin
        client = BBInternal::Client.new(session: { user_id: '11375034', icn: '1012740022V620959' })
        client.authenticate
        client
      end
    end
  end

  let(:client) { @client }

  describe '#list_radiology' do
    it 'gets the radiology records' do
      VCR.use_cassette 'mr_client/bb_internal/get_radiology' do
        radiology_results = client.list_radiology
        expect(radiology_results).to be_an(Array)
        result = radiology_results[0]
        expect(result).to be_a(Hash)
        expect(result).to have_key('procedureName')
      end
    end
  end

  describe '#list_imaging_studies' do
    it 'gets the list of imaging studies' do
      VCR.use_cassette 'mr_client/bb_internal/get_imaging_studies' do
        studies = client.list_imaging_studies
        expect(studies).to be_an(Array)
        expect(studies.first).to have_key('studyIdUrn')
      end
    end
  end

  describe '#request_study' do
    it 'requests a study by study_id' do
      study_id = '453-2487450'
      VCR.use_cassette 'mr_client/bb_internal/request_study' do
        result = client.request_study(study_id)
        expect(result).to be_a(Hash)
        expect(result).to have_key('status')
      end
    end
  end

  describe '#list_images' do
    it 'lists the images for a given study' do
      study_id = '453-2487450'
      VCR.use_cassette 'mr_client/bb_internal/list_images' do
        images = client.list_images(study_id)
        expect(images).to be_an(Array)
        expect(images.first).to be_a(String)
      end
    end
  end

  describe '#get_image' do
    it 'streams an image successfully' do
      study_id = '453-2487450'
      series = '01'
      image = '01'
      yielder = StringIO.new

      VCR.use_cassette 'mr_client/bb_internal/get_image' do
        client.get_image(study_id, series, image, ->(headers) {}, yielder)
        expect(yielder.string).not_to be_empty
      end
    end
  end

  describe '#get_dicom' do
    it 'streams a DICOM zip successfully' do
      study_id = '453-2487450'
      yielder = StringIO.new

      VCR.use_cassette 'mr_client/bb_internal/get_dicom' do
        client.get_dicom(study_id, ->(headers) {}, yielder)
        expect(yielder.string).not_to be_empty
      end
    end
  end

  describe '#get_generate_ccd' do
    it 'requests a CCD be generated and returns the correct structure' do
      VCR.use_cassette 'mr_client/bb_internal/generate_ccd' do
        ccd_list = client.get_generate_ccd(client.session.icn, 'DOE')

        expect(ccd_list).to be_an(Array)
        expect(ccd_list).not_to be_empty

        first_ccd = ccd_list.first
        expect(first_ccd).to be_a(Hash)
        expect(first_ccd).to have_key('dateGenerated')
        expect(first_ccd['dateGenerated']).to be_a(String)

        expect(first_ccd).to have_key('status')
        expect(first_ccd['status']).to be_a(String)
      end
    end
  end

  describe '#get_download_ccd' do
    let(:date) { '2024-10-23T12:42:48.000-0400' }
    let(:expected_url) do
      "#{Settings.mhv.medical_records.host}/mhvapi/v1/bluebutton/healthsummary/#{date}/fileFormat/XML/ccdType/XML"
    end
    let(:response_body) { '<ClinicalDocument>...</ClinicalDocument>' }

    context 'when using VCR' do
      it 'retrieves a previously generated CCD as XML' do
        VCR.use_cassette 'mr_client/bb_internal/download_ccd' do
          ccd = client.get_download_ccd(date)

          expect(ccd).to be_a(String)
          expect(ccd).to include('<ClinicalDocument')
        end
      end
    end

    context 'when verifying headers with WebMock' do
      it 'sends the correct Accept header' do
        stub_request(:get, expected_url)
          .with(headers: { 'Accept' => 'application/xml' })
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/xml' })

        ccd = client.get_download_ccd(date)

        expect(ccd).to be_a(String)
        expect(ccd).to include('<ClinicalDocument')
      end
    end
  end

  describe '#get_study_status' do
    it 'retrieves the status of all study jobs' do
      VCR.use_cassette 'mr_client/bb_internal/study_status' do
        study_job_list = client.get_study_status

        expect(study_job_list).to be_an(Array)
        expect(study_job_list).not_to be_empty

        first_study_job = study_job_list.first
        expect(first_study_job).to be_a(Hash)

        expect(first_study_job).to have_key('status')
        expect(first_study_job['status']).to be_a(String)
        expect(first_study_job).to have_key('studyIdUrn')
        expect(first_study_job['studyIdUrn']).to be_a(String)
      end
    end
  end

  describe '#get_bbmi_notification_setting' do
    it 'retrieves the BBMI notification setting' do
      VCR.use_cassette 'mr_client/bb_internal/get_bbmi_notification_setting' do
        notification_setting = client.get_bbmi_notification_setting

        expect(notification_setting).to be_a(Hash)
        expect(notification_setting).to have_key('flag')
        expect(notification_setting['flag']).to eq(true)
      end
    end
  end

  describe '#get_sei_vital_signs_summary' do
    it 'retrieves the SEI vital signs' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_vital_signs_summary' do
        response = client.get_sei_vital_signs_summary

        expect(response).to be_a(Hash)
        expect(response).to have_key('bloodPreassureReadings')
        expect(response).to have_key('bloodSugarReadings')
        expect(response).to have_key('bodyTemperatureReadings')
        expect(response).to have_key('bodyWeightReadings')
        expect(response).to have_key('cholesterolReadings')
        expect(response).to have_key('heartRateReadings')
        expect(response).to have_key('inrReadings')
        expect(response).to have_key('lipidReadings')
        expect(response).to have_key('painReadings')
        expect(response).to have_key('pulseOximetryReadings')
      end
    end
  end

  describe '#get_sei_allergies' do
    it 'retrieves the SEI allergies' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_allergies' do
        response = client.get_sei_allergies

        expect(response).to be_a(Hash)
        expect(response).to have_key('pojoObject')
        expect(response['pojoObject'][0]).to have_key('allergiesId')
      end
    end
  end

  describe '#get_sei_family_health_history' do
    it 'retrieves the SEI family health history' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_family_health_history' do
        response = client.get_sei_family_health_history

        expect(response).to be_a(Hash)
        expect(response).to have_key('pojoObject')
        expect(response['pojoObject'][0]).to have_key('relationship')
      end
    end
  end

  describe '#get_sei_immunizations' do
    it 'retrieves the SEI immunizations' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_immunizations' do
        response = client.get_sei_immunizations

        expect(response).to be_a(Hash)
        expect(response).to have_key('pojoObject')
        expect(response['pojoObject'][0]).to have_key('immunizationId')
      end
    end
  end

  describe '#get_sei_test_entries' do
    it 'retrieves the SEI test entries' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_test_entries' do
        response = client.get_sei_test_entries

        expect(response).to be_a(Hash)
        expect(response).to have_key('pojoObject')
      end
    end
  end

  describe '#get_sei_medical_events' do
    it 'retrieves the SEI medical events' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_medical_events' do
        response = client.get_sei_medical_events

        expect(response).to be_a(Hash)
        expect(response).to have_key('pojoObject')
        expect(response['pojoObject'][0]).to have_key('medicalEventId')
      end
    end
  end

  describe '#get_sei_military_history' do
    it 'retrieves the SEI miltary history' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_military_history' do
        response = client.get_sei_military_history

        expect(response).to be_a(Hash)
        expect(response).to have_key('pojoObject')
        expect(response['pojoObject'][0]).to have_key('serviceBranch')
      end
    end
  end

  describe '#get_sei_healthcare_providers' do
    it 'retrieves the SEI healthcare providers' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_healthcare_providers' do
        response = client.get_sei_healthcare_providers

        expect(response).to be_an(Array)
        expect(response[0]).to have_key('healthCareProviderId')
      end
    end
  end

  describe '#get_sei_health_insurance' do
    it 'retrieves the SEI health insurance' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_health_insurance' do
        response = client.get_sei_health_insurance

        expect(response).to be_an(Array)
        expect(response[0]).to have_key('healthInsuranceId')
      end
    end
  end

  describe '#get_sei_treatment_facilities' do
    it 'retrieves the SEI treatment facilities' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_treatment_facilities' do
        response = client.get_sei_treatment_facilities

        expect(response).to be_an(Array)
        expect(response[0]).to have_key('treatmentFacilityId')
      end
    end
  end

  describe '#get_sei_food_journal' do
    it 'retrieves the SEI food journal' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_food_journal' do
        response = client.get_sei_food_journal

        expect(response).to be_an(Array)
        expect(response[0]).to have_key('foodJournalId')
      end
    end
  end

  describe '#get_sei_activity_journal' do
    it 'retrieves the SEI activity journal' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_activity_journal' do
        response = client.get_sei_activity_journal

        expect(response).to be_an(Array)
        expect(response[0]).to have_key('activityJournalId')
      end
    end
  end

  describe '#get_sei_medications' do
    it 'retrieves the SEI activity journal' do
      VCR.use_cassette 'mr_client/bb_internal/get_sei_medications' do
        response = client.get_sei_medications

        expect(response).to be_an(Array)
        expect(response[0]).to have_key('medicationId')
      end
    end
  end
end
