# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/bb_internal/client'
require 'stringio'

UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

describe BBInternal::Client do
  let(:client) { @client }

  RSpec.shared_context 'redis setup' do
    let(:redis) { instance_double(Redis::Namespace) }
    let(:study_id) { '453-2487450' }
    let(:uuid) { 'c9396040-23b7-44bc-a505-9127ed968b0d' }
    let(:cached_data) do
      {
        uuid => study_id
      }.to_json
    end
    let(:namespace) { REDIS_CONFIG[:bb_internal_store][:namespace] }
    let(:study_data_key) { 'study_data-11382904' }

    before do
      allow(Redis::Namespace).to receive(:new).with(namespace, redis: $redis).and_return(redis)
      allow(redis).to receive(:get).with(study_data_key).and_return(cached_data)
    end
  end

  context 'using API Gateway endpoints' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(true)
      VCR.use_cassette 'mr_client/bb_internal/apigw_session_auth' do
        @client ||= begin
          client = BBInternal::Client.new(session: { user_id: '11375034', icn: '1012740022V620959' })
          client.authenticate
          client
        end
      end
    end

    describe '#list_radiology' do
      it 'gets the radiology records' do
        VCR.use_cassette 'mr_client/bb_internal/apigw_get_radiology' do
          radiology_results = client.list_radiology
          expect(radiology_results).to be_an(Array)
          result = radiology_results[0]
          expect(result).to be_a(Hash)
          expect(result).to have_key('procedureName')
        end
      end
    end

    describe '#get_bbmi_notification_setting' do
      it 'retrieves the BBMI notification setting' do
        VCR.use_cassette 'mr_client/bb_internal/apigw_get_bbmi_notification_setting' do
          notification_setting = client.get_bbmi_notification_setting

          expect(notification_setting).to be_a(Hash)
          expect(notification_setting).to have_key('flag')
          expect(notification_setting['flag']).to be(true)
        end
      end
    end
  end

  context 'using legacy endpoints' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)
      VCR.use_cassette 'mr_client/bb_internal/session_auth' do
        @client ||= begin
          client = BBInternal::Client.new(session: { user_id: '11375034', icn: '1012740022V620959' })
          client.authenticate
          client
        end
      end
    end

    describe 'session' do
      it 'preserves ICN' do
        expect(client.session.icn).to equal('1012740022V620959')
      end
    end

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
          expect(studies.first).to have_key('studyIdUrn')

          # Check if 'studyIdUrn' was replaced by a UUID
          expect(studies.first['studyIdUrn']).to match(UUID_REGEX)
        end
      end
    end

    describe '#request_study' do
      include_context 'redis setup'

      it 'requests a study by study_id' do
        VCR.use_cassette 'mr_client/bb_internal/request_study' do
          result = client.request_study(uuid)
          expect(result).to be_a(Hash)
          expect(result).to have_key('status')
          expect(result).to have_key('studyIdUrn')

          # 'studyIdUrn' should match a specific UUID
          expect(result['studyIdUrn']).to equal(uuid)
        end
      end
    end

    describe '#list_images' do
      include_context 'redis setup'

      it 'lists the images for a given study' do
        VCR.use_cassette 'mr_client/bb_internal/list_images' do
          images = client.list_images(uuid)
          expect(images).to be_an(Array)
          expect(images.first).to be_a(String)
        end
      end
    end

    describe '#get_image' do
      include_context 'redis setup'

      it 'streams an image successfully' do
        series = '01'
        image = '01'
        yielder = StringIO.new

        VCR.use_cassette 'mr_client/bb_internal/get_image' do
          client.get_image(uuid, series, image, ->(headers) {}, yielder)
          expect(yielder.string).not_to be_empty
        end
      end
    end

    describe '#get_dicom' do
      include_context 'redis setup'

      it 'streams a DICOM zip successfully' do
        yielder = StringIO.new

        VCR.use_cassette 'mr_client/bb_internal/get_dicom' do
          client.get_dicom(uuid, ->(headers) {}, yielder)
          expect(yielder.string).not_to be_empty
        end
      end
    end

    describe '#get_generate_ccd' do
      let(:icn) { '1000000000V000000' }
      let(:last_name_with_space) { 'DOE SMITH' }
      let(:expected_escaped_last_name) { 'DOE%20SMITH' }

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

      it 'ensures the URL contains no spaces by escaping them' do
        # Mock the `perform` method to intercept the URL
        allow(client).to receive(:perform).and_wrap_original do |_original_method, _method, url, _body, _headers|
          # Verify the URL contains no spaces
          expect(url).to include(expected_escaped_last_name)
          expect(url).not_to include(' ')
          # Return a mock response to satisfy the method call
          double('Response', body: [])
        end

        # Call the method
        client.get_generate_ccd(icn, last_name_with_space)
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

          # Check if 'studyIdUrn' was replaced by a UUID
          expect(first_study_job['studyIdUrn']).to match(UUID_REGEX)
        end
      end
    end

    describe '#get_bbmi_notification_setting' do
      it 'retrieves the BBMI notification setting' do
        VCR.use_cassette 'mr_client/bb_internal/get_bbmi_notification_setting' do
          notification_setting = client.get_bbmi_notification_setting

          expect(notification_setting).to be_a(Hash)
          expect(notification_setting).to have_key('flag')
          expect(notification_setting['flag']).to be(true)
        end
      end
    end

    describe '#get_patient' do
      it 'retrieves the patient information by user ID' do
        VCR.use_cassette 'mr_client/bb_internal/get_patient' do
          patient = client.get_patient

          expect(patient).to be_a(Hash)

          expect(patient).to have_key('ipas')
          expect(patient['ipas']).to be_an(Array)
          expect(patient['ipas']).not_to be_empty

          expect(patient).to have_key('facilities')
          expect(patient['facilities']).to be_an(Array)
          expect(patient['facilities']).not_to be_empty

          first_facility = patient['facilities'].first
          expect(first_facility).to be_a(Hash)
          expect(first_facility['facilityInfo']).to have_key('name')
        end
      end

      it 'raises a ServiceError when the patient is not found' do
        empty_response = double('Response', body: nil)
        allow(client).to receive(:perform).and_return(empty_response)

        expect { client.get_patient }.to raise_error(Common::Exceptions::ServiceError) do |error|
          expect(error.errors.first[:detail]).to eq('Patient not found')
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

    describe '#get_demographic_info' do
      it 'retrieves the patient demographic information' do
        VCR.use_cassette 'mr_client/bb_internal/get_demographic_info' do
          demographic_info = client.get_demographic_info

          expect(demographic_info).to be_a(Hash)
          expect(demographic_info).to have_key('content')
          expect(demographic_info['content']).to be_an(Array)
          expect(demographic_info['content']).not_to be_empty

          first_record = demographic_info['content'].first
          expect(first_record).to be_a(Hash)
          expect(first_record).to have_key('firstName')
          expect(first_record['firstName']).to be_a(String)
          expect(first_record).to have_key('lastName')
          expect(first_record['lastName']).to be_a(String)
          expect(first_record).to have_key('dateOfBirthString')
          expect(first_record['dateOfBirthString']).to be_a(String)
          expect(first_record).to have_key('gender')
          expect(first_record['gender']).to be_a(String)
          expect(first_record).to have_key('permCity')
          expect(first_record['permCity']).to be_a(String)
          expect(first_record).to have_key('permState')
          expect(first_record['permState']).to be_a(String)
        end
      end
    end

    describe '#invalid?' do
      let(:session_data) { OpenStruct.new(icn:, patient_id:, expired?: session_expired) }

      context 'when session is expired' do
        let(:session_expired) { true }
        let(:icn) { '1000000000V000000' }
        let(:patient_id) { '12345' }

        it 'returns true' do
          expect(client.send(:invalid?, session_data)).to be true
        end
      end

      context 'when session has no icn' do
        let(:session_expired) { false }
        let(:icn) { nil }
        let(:patient_id) { '12345' }

        it 'returns true' do
          expect(client.send(:invalid?, session_data)).to be true
        end
      end

      context 'when session has no patient_id' do
        let(:session_expired) { false }
        let(:icn) { '1000000000V000000' }
        let(:patient_id) { nil }

        it 'returns true' do
          expect(client.send(:invalid?, session_data)).to be true
        end
      end

      context 'when session is valid' do
        let(:session_expired) { false }
        let(:icn) { '1000000000V000000' }
        let(:patient_id) { '12345' }

        it 'returns false' do
          expect(client.send(:invalid?, session_data)).to be false
        end
      end
    end

    describe '#get_sei_emergency_contacts' do
      it "retrieves the patient's emergency contacts" do
        VCR.use_cassette 'mr_client/bb_internal/get_sei_emergency_contacts' do
          emergency_contacts = client.get_sei_emergency_contacts

          expect(emergency_contacts).to be_an(Array)
          expect(emergency_contacts).not_to be_empty

          first_record = emergency_contacts.first
          expect(first_record).to be_a(Hash)
          expect(first_record).to have_key('firstName')
          expect(first_record['firstName']).to be_a(String)
          expect(first_record).to have_key('lastName')
          expect(first_record['lastName']).to be_a(String)
          expect(first_record).to have_key('contactInfoContactMethod')
          expect(first_record['contactInfoContactMethod']).to be_a(String)
          expect(first_record).to have_key('contactInfoEmail')
          expect(first_record['contactInfoEmail']).to be_a(String)
          expect(first_record).to have_key('addressStreet1')
          expect(first_record['addressStreet1']).to be_a(String)
          expect(first_record).to have_key('addressCity')
          expect(first_record['addressCity']).to be_a(String)
          expect(first_record).to have_key('addressState')
          expect(first_record['addressState']).to be_a(String)
          expect(first_record).to have_key('addressPostalCode')
          expect(first_record['addressPostalCode']).to be_a(String)
        end
      end
    end
  end
end
