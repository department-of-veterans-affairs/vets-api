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
          refresh_session(session)
        end

        def refresh_session(session)
          @session = self.class.client_session.find_or_build(session)
        end

        attr_reader :session

        ##
        # Ensures the MHV based session is not expired or incomplete.
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
        # Creates a session
        #
        # @return [MedicalRecords::ClientSession] if a MR (Medical Records) client session
        #
        def get_session
          # Call the security endpoint to create an MHV session and get a JWT token.
          validate_session_params
          env = get_session_tagged
          jwt = get_jwt_from_headers(env.response_headers)
          decoded_token = decode_jwt_token(jwt)
          session.expires_at = extract_token_expiration(decoded_token)
          @session.class.new(user_id: session.user_id.to_s,
                             icn: session.icn,
                             expires_at: session.expires_at,
                             token: jwt)
        end

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
    end
  end
end
