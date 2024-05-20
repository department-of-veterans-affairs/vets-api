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
      response = perform(:get, "bluebutton/radiology/phr/#{session.patient_id}", nil, token_headers)
      response.body
    end

    private

    ##
    # Override MHVSessionBasedClient's method so we can get the patientId and store it as well.
    #
    def get_session
      new_session = @session.class.new(user_id: 11_383_839,
                                       patient_id: 11_383_893,
                                       expires_at: 'Wed, 15 Jan 2025 00:00:00 GMT',
                                       token: 'ENC(MA0ECJh1RjEgZFMhAgEQC4nF8QKGKGmZuYg7kVN8CGTImSTyeRVyXIeUOtSUP4PoUkdGKwuDnAAn)')

      # # Call MHVSessionBasedClient.get_session
      # session = super

      # # Supplement session with patientId
      # patient_id = get_patient_id
      # session.patient_id = patient_id

      new_session.save
      new_session
    end

    def get_patient_id
      response = perform(:get, "usermgmt/patient/uid/#{@session.user_id}", nil, token_headers)
      response.body
      11_383_893
    end

    ##
    # Override MHVSessionBasedClient's method, because we need more control over the path.
    #
    def get_session_tagged
      response = perform(:get, 'usermgmt/auth/session', nil, auth_headers)
      response.body
    end
  end
end
