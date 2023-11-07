# frozen_string_literal: true

require 'common/client/concerns/mhv_jwt_session_client'

module Common
  module Client
    module Concerns
      ##
      # Module mixin for overriding session logic when making MHV FHIR-based client connections. This mixin itself
      # includes another mixin for handling the JWT-based session logic.
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
        include SentryLogging
        include MHVJwtSessionClient

        LOCK_RETRY_DELAY = 1 # Number of seconds to wait between attempts to acquire a session lock
        RETRY_ATTEMPTS = 10 # How many times to attempt to acquire a session lock

        def incomplete?(session)
          session.icn.blank? || session.patient_fhir_id.blank? || session.token.blank? || session.expires_at.blank?
        end

        def invalid?(session)
          session.expired? || incomplete?(session)
        end

        ##
        # Ensure the upstream MHV/FHIR-based session is not expired or incomplete.
        #
        # @return [MhvFhirSessionClient] instance of `self`
        #
        def authenticate
          raise 'ICN is required for session creation' unless session&.icn

          iteration = 0

          # Loop unless a complete, valid MHV/FHIR session exists, or until max_iterations is reached
          while invalid?(session) && iteration < RETRY_ATTEMPTS
            break if lock_and_get_session # Break out of the loop once a new session is created.

            sleep(LOCK_RETRY_DELAY)

            # Refresh the MHV/FHIR session reference in case another thread has updated it.
            refresh_session(session)
            iteration += 1
          end
          self
        end

        ##
        # Attempt to acquire a redis lock, then create a new MHV/FHIR session. Once the session is created,
        # release the lock.
        #
        # return [Boolean] true if a session was created, otherwise false
        #
        def lock_and_get_session
          redis_lock = obtain_redis_lock(session.icn)
          if redis_lock
            begin
              @session = get_session
              return true
            ensure
              release_redis_lock(redis_lock, session.icn)
            end
          end
          false
        end

        def obtain_redis_lock(user_key)
          lock_key = "mhv_fhir_session_lock:#{user_key}"
          redis_lock = Redis::Namespace.new(REDIS_CONFIG[:mhv_mr_fhir_session_lock][:namespace], redis: $redis)
          success = redis_lock.set(lock_key, 1, nx: true, ex: REDIS_CONFIG[:mhv_mr_fhir_session_lock][:each_ttl])
          return redis_lock if success

          nil
        end

        def release_redis_lock(redis_lock, user_key)
          lock_key = "mhv_fhir_session_lock:#{user_key}"
          redis_lock.del(lock_key)
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
            get_patient_fhir_id(session.token) if session.token && patient_fhir_id.nil?
          rescue => e
            exception ||= e
          end

          new_session = save_session
          raise exception if exception

          new_session
        end

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
          session.patient_fhir_id = fetch_patient_by_subject_id(sessionless_fhir_client(jwt_token),
                                                                decoded_token[0]['subjectId'])
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
          if patient.nil? || patient.entry.empty? || !patient.entry[0].resource.respond_to?(:id)
            raise Common::Exceptions::Unauthorized,
                  detail: 'Patient record not found or does not contain a valid FHIR ID'
          end
          session.patient_fhir_id = patient.entry[0].resource.id
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

        ##
        # Override client_session method to use extended ::ClientSession classes
        #
        module ClassMethods
          ##
          # @return [MedicalRecords::ClientSession] if a MR (Medical Records) client session
          #
          def client_session(klass = nil)
            @client_session ||= klass
          end
        end
      end
    end
  end
end
