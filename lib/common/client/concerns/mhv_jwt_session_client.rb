# frozen_string_literal: true

module Common
  module Client
    module Concerns
      ##
      # Module mixin for overriding session logic when making MHV JWT-based client connections
      #
      # @see MedicalRecords::Client
      #
      # @!attribute [r] session
      #   @return [Hash] a hash containing session information
      #
      module MHVJwtSessionClient
        extend ActiveSupport::Concern
        include SentryLogging

        ##
        # @param session [Hash] a hash containing user_id with which the session will be found or built
        #
        def initialize(session:)
          @session = self.class.client_session.find_or_build(session)
        end

        attr_reader :session

        def incomplete?(session)
          session.icn.blank? || session.patient_fhir_id.blank? || session.token.blank? || session.expires_at.blank?
        end

        ##
        # Ensures the MHV based session is not expired or incomplete.
        #
        # @return [MHVJwtSessionClient] instance of `self`
        #
        def authenticate
          @session = get_session if session.expired? || incomplete?(session)
          self
        end

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
        # Decodes a JWT to get the patient's subjectId, then uses that to fetch their FHIR ID
        #
        # @param jwt_token [String] a JWT token
        # @return [String] the patient's FHIR ID
        #
        def get_patient_fhir_id(jwt_token)
          decoded_token = MhvSessionUtilities.decode_jwt_token(jwt_token)
          session.patient_fhir_id = fetch_patient_by_subject_id(sessionless_fhir_client(jwt_token),
                                                                decoded_token[0]['subjectId'])
          session.expires_at = MhvSessionUtilities.extract_token_expiration(decoded_token)
        end

        ##
        # Calls the MHV security API to get a JWT token.
        #
        # @return [String] the JWT token
        #
        def get_jwt_token
          return session.token unless session.token.nil?

          # Call the security endpoint to create an MHV session and get a JWT token.
          validate_session_params
          env = get_session_tagged
          session.token = MhvSessionUtilities.get_jwt_from_headers(env.response_headers)
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
        # Creates a session
        #
        # @return [MedicalRecords::ClientSession] if a MR (Medical Records) client session
        #
        def get_session
          exception = nil

          perform_phr_refresh

          begin
            jwt_token = get_jwt_token
          rescue => e
            exception ||= e
          end

          begin
            get_patient_fhir_id(jwt_token) if jwt_token && patient_fhir_id.nil?
          rescue => e
            exception ||= e
          end

          new_session = save_session
          raise exception if exception

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

        private

        def validate_session_params
          raise Common::Exceptions::ParameterMissing, 'ICN' if session.icn.blank?
          raise Common::Exceptions::ParameterMissing, 'MHV MR App Token' if config.app_token.blank?
        end

        def get_session_tagged
          Raven.tags_context(error: 'mhv_session')
          env = perform(:post, '/mhvapi/security/v1/login', auth_body, auth_headers)
          Raven.context.tags.delete(:error)
          env
        end

        def jwt_bearer_token
          session.token
        end

        def patient_fhir_id
          session.patient_fhir_id
        end

        def auth_headers
          config.base_request_headers.merge('Content-Type' => 'application/json')
        end

        def auth_body
          {
            'appId' => '103',
            'appToken' => config.app_token,
            'subject' => session.icn,
            'userType' => 'PATIENT',
            'authParams' => {
              'PATIENT_SUBJECT_ID_TYPE' => 'ICN'
            }
          }
        end
      end

      module MhvSessionUtilities
        module_function

        def get_jwt_from_headers(res_headers)
          # Get the JWT token from the headers
          auth_header = res_headers['authorization']
          if auth_header.nil? || !auth_header.start_with?('Bearer ')
            raise Common::Exceptions::Unauthorized, detail: 'Invalid or missing authorization header'
          end

          auth_header.sub('Bearer ', '')
        end

        def decode_jwt_token(jwt_token)
          JWT.decode jwt_token, nil, false
        rescue JWT::DecodeError
          raise Common::Exceptions::Unauthorized, detail: 'Invalid JWT token'
        end

        def extract_token_expiration(decoded_token)
          if decoded_token[0]['exp']
            Time.zone.at(decoded_token[0]['exp']).to_datetime.rfc2822
          else
            1.hour.from_now.rfc2822
          end
        end
      end
    end
  end
end
