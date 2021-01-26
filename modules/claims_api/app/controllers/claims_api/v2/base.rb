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
      helpers ClaimsApi::MPIVerification
      helpers ClaimsApi::HeaderValidation
      helpers ClaimsApi::JsonFormatValidation
      helpers ::OAuthConcerns
      helpers do
        def token
          return if headers['Authorization'].blank?

          Token.new(headers['Authorization'].sub(/Bearer /, '').gsub(/^"|"$/, ''), fetch_aud)
        end

        def target_veteran
          ClaimsApi::Veteran.from_identity(identity: @current_user)
        end

        def render_unauthorized
          raise 'you be unauthorized yo'
        end
      end

      before do
        authenticate
      end
    end
  end
end
