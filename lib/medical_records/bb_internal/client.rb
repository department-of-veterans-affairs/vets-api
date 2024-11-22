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

    ################################################################################
    # User Management APIs
    ################################################################################

    # Retrieves the patient information by user ID.
    # @return [Hash] A hash containing the patient's details
    #
    def get_patient
      response = perform(:get, "usermgmt/patient/uid/#{@session.user_id}", nil, token_headers)
      patient = response.body

      raise Common::Exceptions::ServiceError.new(detail: 'Patient not found') if patient.blank?

      patient
    end

    # Retrieves the BBMI notification setting for the user.
    # @return [Hash] containing:
    #   - flag [Boolean]: Indicates whether the BBMI notification setting is enabled (true) or disabled (false)
    #
    def get_bbmi_notification_setting
      response = perform(:get, 'usermgmt/notification/bbmi', nil, token_headers)
      response.body
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
      response = perform(:get, "bluebutton/radiology/phrList/#{session.patient_id}", nil, token_headers)
      response.body
    end

    ##
    # Get a list of MHV radiology reports from CVIX for the current user. These results do not
    # include VIA reports.
    #
    # @return [Hash] The radiology study list from MHV
    #
    def list_imaging_studies
      response = perform(:get, "bluebutton/study/#{session.patient_id}", nil, token_headers)
      response.body
    end

    ##
    # Request that MHV download an imaging study from CVIX. This will initiate the transfer of
    # the images into MHV for later retrieval from vets-api as DICOM or JPGs.
    #
    # @param [String] icn - The patient's ICN
    # @param [String] study_id - The radiology study to request
    #
    # @return [Hash] The status of the image request, including percent complete
    #
    def request_study(study_id)
      response = perform(:get, "bluebutton/studyjob/#{session.patient_id}/icn/#{session.icn}/studyid/#{study_id}", nil,
                         token_headers)
      response.body
    end

    ##
    # Get a list of images for the provided CVIX radiology study
    #
    # @param [String] study_id - The radiology study from which to retrieve images
    #
    # @return [Hash] The list of images from MHV
    #
    def list_images(study_id)
      response = perform(:get, "bluebutton/studyjob/zip/preview/list/#{session.patient_id}/studyidUrn/#{study_id}", nil,
                         token_headers)
      response.body
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
    def get_image(study_id, series, image, header_callback, yielder)
      uri = URI.join(config.base_path,
                     "bluebutton/external/studyjob/image/studyidUrn/#{study_id}/series/#{series}/image/#{image}")
      streaming_get(uri, token_headers, header_callback, yielder)
    end

    ##
    # Pass-through to get a binary stream of a DICOM zip file. This file can be very large.
    #
    # @param [String] study_id - The radiology study from which to retrieve images
    #
    # @return [void] This method does not return a value. Instead, it yields chunks of the response
    # body via the provided yielder.
    #
    def get_dicom(study_id, header_callback, yielder)
      uri = URI.join(config.base_path, "bluebutton/studyjob/zip/stream/#{session.patient_id}/studyidUrn/#{study_id}")
      streaming_get(uri, token_headers, header_callback, yielder)
    end

    ##
    # @param icn - user icn
    # @param last_name - user last name
    # @return JSON [{ dateGenerated, status, patientId }]
    #
    def get_generate_ccd(icn, last_name)
      response = perform(:get, "bluebutton/healthsummary/#{icn}/#{last_name}/xml", nil, token_headers)
      response.body
    end

    ##
    # @param date - receieved from get_generate_ccd call property dateGenerated (e.g. 2024-10-18T09:55:58.000-0400)
    # @return - Continuity of Care Document in XML format
    #
    def get_download_ccd(date)
      modified_headers = token_headers.dup
      modified_headers['Accept'] = 'application/xml'
      response = perform(:get, "bluebutton/healthsummary/#{date}/fileFormat/XML/ccdType/XML", nil, modified_headers)
      response.body
    end

    # check the status of a study job
    # @return [Array] - [{ status: "COMPLETE", studyIdUrn: "111-1234567" percentComplete: 100, fileSize: "1.01 MB",
    #   startDate: 1729777818853, endDate}]
    #
    def get_study_status
      response = perform(:get, "bluebutton/studyjob/#{session.patient_id}", nil, token_headers)
      response.body
    end

    ################################################################################
    # Self-Entered Information (SEI) APIs
    ################################################################################

    def get_sei_vital_signs_summary
      response = perform(:get, "vitals/summary/#{@session.user_id}", nil, token_headers)
      response.body
    end

    def get_sei_allergies
      response = perform(:get, "healthhistory/allergy/#{@session.user_id}", nil, token_headers)
      response.body
    end

    def get_sei_family_health_history
      response = perform(:get, "healthhistory/healthHistory/#{@session.user_id}", nil, token_headers)
      response.body
    end

    def get_sei_immunizations
      response = perform(:get, "healthhistory/immunization/#{@session.user_id}", nil, token_headers)
      response.body
    end

    def get_sei_test_entries
      response = perform(:get, "healthhistory/testEntry/#{@session.user_id}", nil, token_headers)
      response.body
    end

    def get_sei_medical_events
      response = perform(:get, "healthhistory/medicalEvent/#{@session.user_id}", nil, token_headers)
      response.body
    end

    def get_sei_military_history
      response = perform(:get, "healthhistory/militaryHistory/#{@session.user_id}", nil, token_headers)
      response.body
    end

    def get_sei_healthcare_providers
      response = perform(:get, "getcare/healthCareProvider/#{@session.user_id}", nil, token_headers)
      response.body
    end

    def get_sei_health_insurance
      response = perform(:get, "getcare/healthInsurance/#{@session.user_id}", nil, token_headers)
      response.body
    end

    def get_sei_treatment_facilities
      response = perform(:get, "getcare/treatmentFacility/#{@session.user_id}", nil, token_headers)
      response.body
    end

    def get_sei_food_journal
      response = perform(:get, "journal/journals/#{@session.user_id}", nil, token_headers)
      response.body
    end

    def get_sei_activity_journal
      response = perform(:get, "journal/activityjournals/#{@session.user_id}", nil, token_headers)
      response.body
    end

    def get_sei_medications
      response = perform(:get, "pharmacy/medications/#{@session.user_id}", nil, token_headers)
      response.body
    end

    private

    ##
    # Overriding this to ensure a unique namespace for the redis lock.
    #
    def session_config_key
      :mhv_mr_bb_session_lock
    end

    ##
    # Overriding MHVSessionBasedClient's method so we can get the patientId and store it as well.
    #
    def get_session
      # Pull ICN out of the session var before it is overwritten in the super's save
      icn = session.icn

      # Call MHVSessionBasedClient.get_session
      @session = super

      # Supplement session with patientId
      patient = get_patient
      session.patient_id = patient['ipas']&.first&.dig('patientId')
      # Put ICN back into the session
      session.icn = icn

      session.save
      session
    end

    ##
    # Overriding MHVSessionBasedClient's method, because we need more control over the path.
    #
    def get_session_tagged
      perform(:get, 'usermgmt/auth/session', nil, auth_headers)
    end
  end
end
