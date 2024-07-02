# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'medical_records/bb_internal/client_session'
require 'medical_records/bb_internal/configuration'

module BBInternal
  ##
  # Core class responsible for PHR Manager API interface operations
  #
  class Client < Common::Client::Base
    include Common::Client::Concerns::MHVSessionBasedClient

    configuration BBInternal::Configuration
    client_session BBInternal::ClientSession

    def get_radiology
      response = perform(:get, "bluebutton/radiology/phrList/#{session.patient_id}", nil, token_headers)
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

      response.body['ipas']&.first&.dig('patientId')

      # TODO: Raise an error if patient_id is nil
      # raise NoPatientIdError, 'No patientId found' if patient_id.nil?
    end

    ##
    # Override MHVSessionBasedClient's method, because we need more control over the path.
    #
    def get_session_tagged
      perform(:get, 'usermgmt/auth/session', nil, auth_headers)
    end
  end
end
