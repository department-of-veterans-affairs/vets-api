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
        # Creates a session from the request headers
        #
        # @return [MedicalRecords::ClientSession] if a MR (Medical Records) client session
        #
        def get_session
          env = get_session_tagged
          # req_headers = env.request_headers
          res_headers = env.response_headers
          jwt_token = res_headers['authorization'].sub('Bearer ', '')
          @session.class.new(user_id: session.user_id.to_s,
                             #  expires_at: res_headers['expires'],
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
