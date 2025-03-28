# frozen_string_literal: true

require 'common/client/concerns/mhv_locked_session_client'

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
        include MhvLockedSessionClient

        protected

        def user_key
          session.icn
        end

        def session_config_key
          :mhv_mr_fhir_session_lock
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

        private

        def get_jwt_from_headers(res_headers)
          # Get the JWT token from the headers
          auth_header = if Flipper.enabled?(:mhv_medical_records_migrate_to_api_gateway)
                          res_headers['x-amzn-remapped-authorization']
                        else
                          res_headers['authorization']
                        end
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

        def validate_session_params
          raise Common::Exceptions::ParameterMissing, 'ICN' if session.icn.blank?
          raise Common::Exceptions::ParameterMissing, 'MHV MR App Token' if config.app_token.blank?
        end

        def get_session_tagged
          Sentry.set_tags(error: 'mhv_session')
          env = if Flipper.enabled?(:mhv_medical_records_migrate_to_api_gateway)
                  perform(:post, '/v1/security/login', auth_body, auth_headers)
                else
                  perform(:post, '/mhvapi/security/v1/login', auth_body, auth_headers)
                end
          Sentry.get_current_scope.tags.delete(:error)
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
          if Flipper.enabled?(:mhv_medical_records_migrate_to_api_gateway)
            config.base_request_headers.merge('x-api-key' => Settings.mhv.medical_records.x_api_key)
          end
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
