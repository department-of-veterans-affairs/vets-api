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

        ##
        # Ensures the MHV based session is not expired
        #
        # @return [MHVJwtSessionClient] instance of `self`
        #
        def authenticate
          if session.expired?
            @session = get_session
            @session.save
          end
          self
        end

        ##
        # Decodes a JWT to get the patient's subjectId, then uses that to fetch their FHIR ID
        #
        # @param jwt_token [String] a JWT token
        # @return [String] the patient's FHIR ID
        #
        def get_patient_fhir_id(jwt_token)
          decoded_token = begin
            JWT.decode jwt_token, nil, false
          rescue JWT::DecodeError
            raise Common::Exceptions::Unauthorized, 'Invalid JWT token'
          end

          subject_id = decoded_token[0]['subjectId']
          raise Common::Exceptions::Unauthorized, 'JWT token does not contain subjectId' if subject_id.nil?

          # Get the patient's FHIR ID
          fhir_client = sessionless_fhir_client(jwt_token)
          patient = get_patient_by_identifier(fhir_client, subject_id)
          if patient.nil? || patient.entry.empty? || !patient.entry[0].resource.respond_to?(:id)
            raise Common::Exceptions::Unauthorized, 'Patient record not found or does not contain a valid FHIR ID'
          end

          patient.entry[0].resource.id
        end

        ##
        # Creates a session from the request headers
        #
        # @return [MedicalRecords::ClientSession] if a MR (Medical Records) client session
        #
        def get_session
          env = get_session_tagged
          # req_headers = env.request_headers
          res_headers = env.response_headers

          # Get the JWT token from the headers
          auth_header = res_headers['authorization']
          if auth_header.nil? || !auth_header.start_with?('Bearer ')
            raise Common::Exceptions::Unauthorized, 'Invalid or missing authorization header'
          end

          jwt_token = auth_header.sub('Bearer ', '')

          patient_fhir_id = get_patient_fhir_id(jwt_token)

          expires = (DateTime.now + Rational(3600, 86_400)).rfc2822
          @session.class.new(user_id: session.user_id.to_s,
                             patient_fhir_id:,
                             # TODO: If MHV updates API to include this field, use the version from their headers
                             #  expires_at: res_headers['expires'],
                             expires_at: expires,
                             token: jwt_token)
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
            'subject' => session.user_id.to_s,
            'userType' => 'PATIENT',
            'authParams' => {
              'PATIENT_SUBJECT_ID_TYPE' => 'USER_PROFILE_ID'
            }
          }
        end
      end
    end
  end
end
