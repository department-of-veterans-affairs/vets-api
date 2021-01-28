require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'rest-client'
require 'saml/settings_service'
require 'sentry_logging'
require 'oidc/key_service'
require 'okta/user_profile'
require 'okta/service'
require 'jwt'
require 'oauth_concerns'

module ClaimsApi
  module V2
    class Base < Grape::API
      format :json
      rescue_from ::Common::Exceptions::Unauthorized do |e|
        error!({ errors: ClaimsApi::Entities::V2::ErrorEntity.represent(e.errors) }, 401)
      end
      rescue_from :all do |e|
        base_error = { title: 'Internal server error', detail: e.message, code: '500', status: '500' }
        error!({ errors: [ClaimsApi::Entities::V2::ErrorEntity.represent(base_error)] }, 500)
      end

      helpers ClaimsApi::MPIVerification
      helpers ClaimsApi::HeaderValidation
      helpers ClaimsApi::JsonFormatValidation
      helpers ::OAuthConcerns
      helpers do
        def authenticate
          super
        rescue ::Common::Exceptions::Unauthorized => e
          raise e
        rescue => e
          raise ::Common::Exceptions::Unauthorized, detail: 'Signature has expired'
        end

        def token
          return if headers['Authorization'].blank?

          Token.new(headers['Authorization'].sub(/Bearer /, '').gsub(/^"|"$/, ''), fetch_aud)
        end

        def target_veteran
          ClaimsApi::Veteran.from_identity(identity: @current_user)
        end

        def render_unauthorized
          raise ::Common::Exceptions::Unauthorized
        end

        def source_name
          "#{target_veteran.first_name} #{target_veteran.last_name}"
        end
      end

      mount ClaimsApi::V2::Claims
      mount ClaimsApi::V2::Forms::DisabilityCompensation
      mount ClaimsApi::V2::Forms::IntentToFile
      mount ClaimsApi::V2::Forms::PowerOfAttorney

      add_swagger_documentation \
        mount_path: '/docs/v2/api',
        info: {
          version: '2.0.0',
          title: 'Benefits Claims',
          description: '',
          contact_name: 'VA API Benefits Team',
          terms_of_service_url: 'https://developer.va.gov/terms-of-service',
          license: 'Creative Commons'
        }
    end
  end
end
