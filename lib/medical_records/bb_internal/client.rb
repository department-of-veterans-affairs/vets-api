# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'common/client/concerns/streaming_client'
require 'medical_records/bb_internal/client_session'
require 'medical_records/bb_internal/configuration'

module BBInternal
  ##
  # Core class responsible for MHV internal Blue Button API interface operations
  #
  class Client < Common::Client::Base
    include Common::Client::Concerns::MHVSessionBasedClient
    include Common::Client::Concerns::StreamingClient

    configuration BBInternal::Configuration
    client_session BBInternal::ClientSession

    USERMGMT_BASE_PATH = "#{Settings.mhv.api_gateway.hosts.usermgmt}/v1/".freeze
    BLUEBUTTON_BASE_PATH = "#{Settings.mhv.api_gateway.hosts.bluebutton}/v1/".freeze

    ################################################################################
    # User Management APIs
    ################################################################################

    # Retrieves the patient information by user ID.
    # @return [Hash] A hash containing the patient's details
    #
    def get_patient
      with_custom_base_path(USERMGMT_BASE_PATH) do
        response = perform(:get, "usermgmt/patient/uid/#{@session.user_id}", nil, token_headers)
        patient = response.body

        raise Common::Exceptions::ServiceError.new(detail: 'Patient not found') if patient.blank?

        patient
      end
    end

    # Retrieves the BBMI notification setting for the user.
    # @return [Hash] containing:
    #   - flag [Boolean]: Indicates whether the BBMI notification setting is enabled (true) or disabled (false)
    #
    def get_bbmi_notification_setting
      with_custom_base_path(USERMGMT_BASE_PATH) do
        response = perform(:get, 'usermgmt/notification/bbmi', nil, token_headers)
        response.body
      end
    end

    ################################################################################
    # Blue Button Medical Imaging (BBMI) APIs
    ################################################################################

    ##
    # Get a list of MHV radiology reports from VIA for the current user. These results do not
    # include CVIX reports.
    #
    # @return [Hash] The radiology report list from MHV
    #
    def list_radiology
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "bluebutton/radiology/phrList/#{session.patient_id}", nil, token_headers)
        response.body
      end
    end

    ##
    # Get a list of MHV radiology reports from CVIX for the current user. These results do not
    # include VIA reports.
    #
    # @return [Hash] The radiology study list from MHV
    #
    def list_imaging_studies
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "bluebutton/study/#{session.patient_id}", nil, token_headers)
        data = response.body
        map_study_ids(data)
      end
    end

    ##
    # Request that MHV download an imaging study from CVIX. This will initiate the transfer of
    # the images into MHV for later retrieval from vets-api as DICOM or JPGs.
    #
    # @param [String] icn - The patient's ICN
    # @param [String] id - The uuid of the radiology study to request
    #
    # @return [Hash] The status of the image request, including percent complete
    #
    def request_study(id)
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        # Fetch the original studyIdUrn from the Redis cache
        study_id = get_study_id_from_cache(id)

        # Perform the API call with the original studyIdUrn
        response = perform(
          :get, "bluebutton/studyjob/#{session.patient_id}/icn/#{session.icn}/studyid/#{study_id}", nil,
          token_headers
        )
        data = response.body

        # Transform the response to replace the studyIdUrn with the UUID
        data['studyIdUrn'] = id if data.is_a?(Hash) && data['studyIdUrn'] == study_id

        data
      end
    end

    ##
    # Get a list of images for the provided CVIX radiology study
    #
    # @param [String] id - The uuid of the radiology study from which to retrieve images
    #
    # @return [Hash] The list of images from MHV
    #
    def list_images(id)
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        study_id = get_study_id_from_cache(id)
        response = perform(
          :get, "bluebutton/studyjob/zip/preview/list/#{session.patient_id}/studyidUrn/#{study_id}", nil,
          token_headers
        )
        response.body
      end
    end

    ##
    # Pass-through to get a binary stream of a radiology image JPG file.
    #
    # @param [String] study_id - The radiology study from which to retrieve images
    # @param [String] series - The series number, e.g. "01"
    # @param [String] image - The image number, e.g. "01"
    # @param [Enumerator::Yielder] yielder - An enumerator yielder used to yield chunks of the response body.
    #
    # @return [void] This method does not return a value. Instead, it yields chunks of the response
    # body via the provided yielder.
    #
    def get_image(id, series, image, header_callback, yielder)
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        study_id = get_study_id_from_cache(id)
        uri = URI.join(config.base_path,
                       "bluebutton/external/studyjob/image/studyidUrn/#{study_id}/series/#{series}/image/#{image}")
        streaming_get(uri, token_headers, header_callback, yielder)
      end
    end

    ##
    # Pass-through to get a binary stream of a DICOM zip file. This file can be very large.
    #
    # @param [String] study_id - The radiology study from which to retrieve images
    #
    # @return [void] This method does not return a value. Instead, it yields chunks of the response
    # body via the provided yielder.
    #
    def get_dicom(id, header_callback, yielder)
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        study_id = get_study_id_from_cache(id)
        uri = URI.join(config.base_path,
                       "bluebutton/studyjob/zip/stream/#{session.patient_id}/studyidUrn/#{study_id}")
        streaming_get(uri, token_headers, header_callback, yielder)
      end
    end

    ##
    # @param icn - user icn
    # @param last_name - user last name
    # @return JSON [{ dateGenerated, status, patientId }]
    #
    def get_generate_ccd(icn, last_name)
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        escaped_last_name = URI::DEFAULT_PARSER.escape(last_name)
        response = perform(:get, "bluebutton/healthsummary/#{icn}/#{escaped_last_name}/xml", nil, token_headers)
        response.body
      end
    end

    ##
    # @param date - receieved from get_generate_ccd call property dateGenerated (e.g. 2024-10-18T09:55:58.000-0400)
    # @return - Continuity of Care Document in XML format
    #
    def get_download_ccd(date)
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        modified_headers = token_headers.dup
        modified_headers['Accept'] = 'application/xml'
        response = perform(:get, "bluebutton/healthsummary/#{date}/fileFormat/XML/ccdType/XML", nil, modified_headers)
        response.body
      end
    end

    ##
    # check the status of a study job
    # @return [Array] - [{ status: "COMPLETE", studyIdUrn: "111-1234567" percentComplete: 100, fileSize: "1.01 MB",
    #   startDate: 1729777818853, endDate}]
    #
    def get_study_status
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "bluebutton/studyjob/#{session.patient_id}", nil, token_headers)
        data = response.body
        map_study_ids(data)
      end
    end

    ################################################################################
    # Self-Entered Information (SEI) APIs
    ################################################################################

    def get_sei_vital_signs_summary
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "vitals/summary/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    def get_sei_allergies
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "healthhistory/allergy/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    def get_sei_family_health_history
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "healthhistory/healthHistory/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    def get_sei_immunizations
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "healthhistory/immunization/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    def get_sei_test_entries
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "healthhistory/testEntry/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    def get_sei_medical_events
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "healthhistory/medicalEvent/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    def get_sei_military_history
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "healthhistory/militaryHistory/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    def get_sei_healthcare_providers
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "getcare/healthCareProvider/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    def get_sei_health_insurance
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "getcare/healthInsurance/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    def get_sei_treatment_facilities
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "getcare/treatmentFacility/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    def get_sei_food_journal
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "journal/journals/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    def get_sei_activity_journal
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "journal/activityjournals/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    def get_sei_medications
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, "pharmacy/medications/#{@session.user_id}", nil, token_headers)
        response.body
      end
    end

    # Retrieves the patient demographic information
    # @return [Hash] A hash containing the patient's demographic information
    #
    def get_demographic_info
      with_custom_base_path(BLUEBUTTON_BASE_PATH) do
        response = perform(:get, 'bluebutton/external/phrdemographic', nil, token_headers)
        response.body
      end
    end

    def get_sei_emergency_contacts
      response = perform(:get, "usermgmt/emergencycontacts/#{@session.user_id}", nil, token_headers)
      response.body
    end

    private

    def with_custom_base_path(custom_base_path)
      if Flipper.enabled?(:mhv_medical_records_migrate_to_api_gateway) && custom_base_path
        BBInternal::Configuration.custom_base_path = custom_base_path
      end
      yield
    end

    def token_headers
      super.merge('x-api-key' => config.x_api_key)
    end

    def auth_headers
      super.merge('x-api-key' => config.x_api_key)
    end

    ##
    # Overriding this to ensure a unique namespace for the redis lock.
    #
    def session_config_key
      :mhv_mr_bb_session_lock
    end

    def study_data_key
      "study_data-#{session.patient_id}"
    end

    def bb_redis
      namespace = REDIS_CONFIG[:bb_internal_store][:namespace]
      Redis::Namespace.new(namespace, redis: $redis)
    end

    def get_study_data_from_cache
      bb_redis.get(study_data_key)
    end

    def get_study_id_from_cache(id)
      study_data = get_study_data_from_cache

      if study_data
        study_data_hash = JSON.parse(study_data)
        id = id.to_s
        study_id = study_data_hash[id]

        study_id || raise(Common::Exceptions::RecordNotFound, id)
      else
        # throw 400 for FE to know to refetch the list
        raise Common::Exceptions::InvalidResource, 'Study data map'
      end
    end

    ##
    # Takes an array of objects with a studyIdUrn field. For each object, if the studyIdUrn is already mapped to a
    # cached UUID in redis, simply replace all the studyIdUrn with its mapped value. If the value is not yet mapped
    # in redis, create the mapped UUID first, then replace the studyIdUrn in the object. This is to prevent the
    # study_id from being exposed to the client.
    #
    # @param [Array] data - An array which contains objects that have a studyIdUrn field.
    #
    # @return [Array] A modified array in which all the objects have has studyIdUrn mapped to a UUID.
    #
    def map_study_ids(data)
      study_data_cached = get_study_data_from_cache
      study_data_hash = JSON.parse(study_data_cached) if study_data_cached
      id_uuid_map = study_data_hash || {}

      modified_data = data.map do |obj|
        study_id = obj['studyIdUrn']

        existing_uuid = study_data_hash&.key(study_id.to_s)

        if existing_uuid
          obj['studyIdUrn'] = existing_uuid
        else
          new_uuid = SecureRandom.uuid
          id_uuid_map[new_uuid] = study_id
          obj['studyIdUrn'] = new_uuid
        end
        obj
      end

      # Store in redis with a ttl of 3 days
      bb_redis.set(study_data_key, id_uuid_map.to_json, nx: false, ex: 259_200)

      modified_data
    end

    ##
    # Overriding MHVSessionBasedClient's method to ensure the thread blocks if ICN or patient ID are not yet set.
    #
    def invalid?(session)
      super(session) || session.icn.blank? || session.patient_id.blank?
    end

    ##
    # Overriding MHVSessionBasedClient's method so we can get the patientId and store it as well.
    #
    def get_session
      # Call the superclass method to update or create the session
      super

      # Add or update patientId in the session
      patient_id = get_patient.dig('ipas', 0, 'patientId')
      session.patient_id = patient_id if patient_id

      session.save
      session
    end

    ##
    # Overriding MHVSessionBasedClient's method, because we need more control over the path.
    #
    def get_session_tagged
      with_custom_base_path(USERMGMT_BASE_PATH) do
        perform(:get, 'usermgmt/auth/session', nil, auth_headers)
      end
    end
  end
end
