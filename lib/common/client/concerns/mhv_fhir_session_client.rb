# frozen_string_literal: true

require 'common/client/concerns/mhv_jwt_session_client'

module Common
  module Client
    module Concerns
      ##
      # Module mixin for overriding session logic when making MHV JWT/FHIR-based client connections.
      #
      # All refrences to "session" in this module refer to the upstream MHV/FHIR session.
      #
      # @see MedicalRecords::Client
      #
      # @!attribute [r] session
      #   @return [Hash] a hash containing session information
      #
      module MhvFhirSessionClient
        extend ActiveSupport::Concern
        include MHVJwtSessionClient

        protected

        LOCK_RETRY_DELAY = 1 # Number of seconds to wait between attempts to acquire a session lock
        RETRY_ATTEMPTS = 10 # How many times to attempt to acquire a session lock

        def incomplete?(session)
          session.icn.blank? || session.patient_fhir_id.blank? || session.token.blank? || session.expires_at.blank?
        end

        def invalid?(session)
          session.expired? || incomplete?(session)
        end

        ##
        # Creates and saves an MHV/FHIR session for a patient. If any step along the way fails, save
        # the partial session before raising the exception.
        #
        # @return [MedicalRecords::ClientSession] if a MR (Medical Records) client session
        #
        def get_session
          exception = nil

          perform_phr_refresh

          begin
            # Call MHVJwtSessionClient's get_session method for JWT-session creation.
            jwt_session = super
            session.token = jwt_session.token
            session.expires_at = jwt_session.expires_at
          rescue => e
            exception ||= e
          end

          begin
            # If :patient_not_found is returned from the FHIR call, the patient_fhir_id is left nil
            # and handled later.
            get_patient_fhir_id(session.token) if session.token && patient_fhir_id.nil?
          rescue => e
            exception ||= e
          end

          new_session = save_session
          raise exception if exception

          new_session
        end

        private

        ##
        # Checks to see if a PHR refresh is necessary, performs the refresh, and updates the refresh timestamp.
        #
        # @return [DateTime] the refresh timestamp
        #
        def perform_phr_refresh
          return unless session.refresh_time.nil?

          # Perform an async PHR refresh for the user. This job will not raise any errors, it only logs them.
          MHV::PhrUpdateJob.perform_async(session.icn, session.user_id)
          # Record that the refresh has happened for this session. Don't run this more than once per session duration.
          session.refresh_time = DateTime.now
        end

        ##
        # Decodes a JWT to get the patient's subjectId, then uses that to fetch their FHIR ID
        #
        # @param jwt_token [String] a JWT token
        # @return [String] the patient's FHIR ID
        #
        def get_patient_fhir_id(jwt_token)
          decoded_token = decode_jwt_token(jwt_token)
          patient = fetch_patient_by_subject_id(sessionless_fhir_client(jwt_token),
                                                decoded_token[0]['subjectId'])
          session.patient_fhir_id = patient if patient != :patient_not_found
        end

        ##
        # Fetch a Patient FHIR record by subjectId
        #
        # @param fhir_client [FHIR::Client] a FHIR client with which to get the record
        # @param subject_id [String] the patient's subjectId from the JWT
        # @return [FHIR::Patient] the patient's FHIR record
        #
        def fetch_patient_by_subject_id(fhir_client, subject_id)
          raise Common::Exceptions::Unauthorized, detail: 'JWT token does not contain subjectId' if subject_id.nil?

          # Get the patient's FHIR ID
          patient = get_patient_by_identifier(fhir_client, subject_id)

          return :patient_not_found if patient == :patient_not_found

          if patient.nil? || patient.entry.empty? || !patient.entry[0].resource.respond_to?(:id)
            raise Common::Exceptions::Unauthorized,
                  detail: 'Patient record not found or does not contain a valid FHIR ID'
          end

          patient.entry[0].resource.id
        end

        ##
        # Takes information from the session variable and saves a new session instance in redis.
        #
        # @return [MedicalRecords::ClientSession] the updated session
        #
        def save_session
          new_session = @session.class.new(user_id: session.user_id.to_s,
                                           patient_fhir_id: session.patient_fhir_id,
                                           icn: session.icn,
                                           expires_at: session.expires_at,
                                           token: session.token,
                                           refresh_time: session.refresh_time)
          new_session.save
          new_session
        end
      end
    end
  end
end
