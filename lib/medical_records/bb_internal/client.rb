# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'common/client/concerns/streaming_client'
require 'medical_records/bb_internal/client_session'
require 'medical_records/bb_internal/configuration'

module BBInternal
  ##
  # Core class responsible for PHR Manager API interface operations
  #
  class Client < Common::Client::Base
    include Common::Client::Concerns::MHVSessionBasedClient
    include Common::Client::Concerns::StreamingClient

    configuration BBInternal::Configuration
    client_session BBInternal::ClientSession

    def list_radiology
      response = perform(:get, "bluebutton/radiology/phrList/#{session.patient_id}", nil, token_headers)
      response.body
    end

    def dicom(header_callback, yielder)
      uri = URI.join(config.base_path, 'bluebutton/studyjob/zip/stream/11383893/studyidUrn/453-2485299')
      streaming_get(uri, token_headers, header_callback, yielder)
    end

    def get_image(study_id, series, image, header_callback, yielder)
      uri = URI.join(config.base_path,
                     "bluebutton/external/studyjob/image/studyidUrn/#{study_id}/series/#{series}/image/#{image}")
      streaming_get(uri, token_headers, header_callback, yielder)
    end

    def list_imaging_studies
      response = perform(:get, "bluebutton/study/#{session.patient_id}", nil, token_headers)
      response.body
    end

    def request_study(icn, study_id)
      response = perform(:get, "bluebutton/studyjob/#{session.patient_id}/icn/#{icn}/studyid/#{study_id}", nil,
                         token_headers)
      response.body
    end

    def list_images(study_id)
      response = perform(:get, "bluebutton/studyjob/zip/preview/list/#{session.patient_id}/studyidUrn/#{study_id}", nil,
                         token_headers)
      response.body
    end

    private

    ##
    # Override this to ensure a unique namespace for the redis lock.
    #
    def session_config_key
      :mhv_mr_bb_session_lock
    end

    ##
    # Override MHVSessionBasedClient's method so we can get the patientId and store it as well.
    #
    def get_session
      # Call MHVSessionBasedClient.get_session
      @session = super

      # Supplement session with patientId
      session.patient_id = get_patient_id

      session.save
      session
    end

    def get_patient_id
      response = perform(:get, "usermgmt/patient/uid/#{@session.user_id}", nil, token_headers)

      patient_id = response.body['ipas']&.first&.dig('patientId')

      raise Common::Exceptions::ServiceError.new(detail: 'Patient ID not found for user') if patient_id.blank?

      patient_id
    end

    ##
    # Override MHVSessionBasedClient's method, because we need more control over the path.
    #
    def get_session_tagged
      perform(:get, 'usermgmt/auth/session', nil, auth_headers)
    end
  end
end
