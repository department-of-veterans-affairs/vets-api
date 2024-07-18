# frozen_string_literal: true

require 'sign_in/logingov/configuration'
require 'sign_in/logingov/errors'
require 'mockdata/writer'

module SignIn
  module Logingov
    class Service < Common::Client::Base
      configuration Configuration

      DEFAULT_SCOPES = [
        PROFILE_SCOPE = 'profile',
        VERIFIED_AT_SCOPE = 'profile:verified_at',
        ADDRESS_SCOPE = 'address',
        EMAIL_SCOPE = 'email',
        OPENID_SCOPE = 'openid',
        SSN_SCOPE = 'social_security_number'
      ].freeze

      OPTIONAL_SCOPES = [ALL_EMAILS_SCOPE = 'all_emails'].freeze

      attr_reader :optional_scopes

      def initialize(optional_scopes: [])
        @optional_scopes = valid_optional_scopes(optional_scopes)
        super()
      end

      def render_auth(state: SecureRandom.hex,
                      acr: Constants::Auth::LOGIN_GOV_IAL1,
                      operation: Constants::Auth::AUTHORIZE)

        Rails.logger.info('[SignIn][Logingov][Service] Rendering auth, ' \
                          "state: #{state}, acr: #{acr}, operation: #{operation}, " \
                          "optional_scopes: #{optional_scopes}")

        scope = (DEFAULT_SCOPES + optional_scopes).join(' ')
        RedirectUrlGenerator.new(redirect_uri: auth_url, params_hash: auth_params(acr, state, scope)).perform
      end

      def render_logout(client_logout_redirect_uri)
        "#{sign_out_url}?#{sign_out_params(config.logout_redirect_uri,
                                           encode_logout_redirect(client_logout_redirect_uri)).to_query}"
      end

      def render_logout_redirect(state)
        state_hash = JSON.parse(Base64.decode64(state))
        logout_redirect_uri = state_hash['logout_redirect']
        RedirectUrlGenerator.new(redirect_uri: URI.parse(logout_redirect_uri).to_s).perform
      end

      def token(code)
        response = perform(
          :post, config.token_path, token_params(code), { 'Content-Type' => 'application/json' }
        )
        Rails.logger.info("[SignIn][Logingov][Service] Token Success, code: #{code}")
        parse_token_response(response.body)
      rescue Common::Client::Errors::ClientError => e
        raise_client_error(e, 'Token')
      end

      def user_info(token)
        response = perform(:get, config.userinfo_path, nil, { 'Authorization' => "Bearer #{token}" })
        log_credential(response.body) if config.log_credential

        OpenStruct.new(response.body)
      rescue Common::Client::Errors::ClientError => e
        raise_client_error(e, 'UserInfo')
      end

      def normalized_attributes(user_info, credential_level)
        {
          logingov_uuid: user_info.sub,
          current_ial: credential_level.current_ial,
          max_ial: credential_level.max_ial,
          ssn: user_info.social_security_number&.tr('-', ''),
          birth_date: user_info.birthdate,
          first_name: user_info.given_name,
          last_name: user_info.family_name,
          address: normalize_address(user_info.address),
          csp_email: user_info.email,
          all_csp_emails: user_info.all_emails,
          multifactor: true,
          service_name: config.service_name,
          authn_context: get_authn_context(credential_level.current_ial),
          auto_uplevel: credential_level.auto_uplevel
        }
      end

      private

      def auth_params(acr, state, scope)
        {
          acr_values: acr,
          client_id: config.client_id,
          nonce: random_seed,
          prompt: config.prompt,
          redirect_uri: config.redirect_uri,
          response_type: config.response_type,
          scope:,
          state:
        }
      end

      def normalize_address(address)
        return unless address

        street_array = address[:street_address].split("\n")
        {
          street: street_array[0],
          street2: street_array[1],
          postal_code: address[:postal_code],
          state: address[:region],
          city: address[:locality],
          country: united_states_country_code
        }
      end

      def united_states_country_code
        'USA'
      end

      def log_credential(credential)
        MockedAuthentication::Mockdata::Writer.save_credential(credential:, credential_type: 'logingov')
      end

      def raise_client_error(client_error, function_name)
        status = client_error.status
        description = client_error.body && client_error.body[:error]
        raise client_error, "[SignIn][Logingov][Service] Cannot perform #{function_name} request, " \
                            "status: #{status}, description: #{description}"
      end

      def parse_token_response(response_body)
        access_token = response_body[:access_token]
        logingov_acr = jwt_decode(response_body[:id_token])['acr']
        { access_token:, logingov_acr: }
      end

      def jwt_decode(encoded_jwt)
        verify_expiration = true
        JWT.decode(
          encoded_jwt,
          nil,
          verify_expiration,
          { verify_expiration:, algorithm: config.jwt_decode_algorithm, jwks: public_jwks }
        ).first
      rescue JWT::JWKError
        raise Errors::PublicJWKError, '[SignIn][Logingov][Service] Public JWK is malformed'
      rescue JWT::VerificationError
        raise Errors::JWTVerificationError, '[SignIn][Logingov][Service] JWT body does not match signature'
      rescue JWT::ExpiredSignature
        raise Errors::JWTExpiredError, '[SignIn][Logingov][Service] JWT has expired'
      rescue JWT::DecodeError
        raise Errors::JWTDecodeError, '[SignIn][Logingov][Service] JWT is malformed'
      end

      def public_jwks
        @public_jwks ||= Rails.cache.fetch(config.jwks_cache_key, expires_in: config.jwks_cache_expiration) do
          response = perform(:get, config.public_jwks_path, nil, nil)
          Rails.logger.info('[SignIn][Logingov][Service] Get Public JWKs Success')

          parse_public_jwks(response:)
        end
      rescue Common::Client::Errors::ClientError => e
        raise_client_error(e, 'Get Public JWKs')
      end

      def parse_public_jwks(response:)
        JWT::JWK::Set.new(response.body).select { |key| key[:use] == 'sig' }
      end

      def get_authn_context(current_ial)
        current_ial == Constants::Auth::IAL_TWO ? Constants::Auth::LOGIN_GOV_IAL2 : Constants::Auth::LOGIN_GOV_IAL1
      end

      def auth_url
        "#{config.base_path}/#{config.auth_path}"
      end

      def token_url
        "#{config.base_path}/#{config.token_path}"
      end

      def sign_out_url
        "#{config.base_path}/#{config.logout_path}"
      end

      def sign_out_params(redirect_uri, state)
        {
          client_id: config.client_id,
          post_logout_redirect_uri: redirect_uri,
          state:
        }
      end

      def token_params(code)
        {
          grant_type: config.grant_type,
          code:,
          client_assertion_type: config.client_assertion_type,
          client_assertion: client_assertion_jwt
        }.to_json
      end

      def encode_logout_redirect(logout_redirect_uri)
        Base64.encode64(logout_state_payload(logout_redirect_uri).to_json)
      end

      def logout_state_payload(logout_redirect_uri)
        {
          logout_redirect: logout_redirect_uri,
          seed: random_seed
        }
      end

      def client_assertion_jwt
        jwt_payload = {
          iss: config.client_id,
          sub: config.client_id,
          aud: token_url,
          jti: SecureRandom.hex,
          nonce: random_seed,
          exp: Time.now.to_i + config.client_assertion_expiration_seconds
        }
        JWT.encode(jwt_payload, config.ssl_key, 'RS256')
      end

      def random_seed
        @random_seed ||= SecureRandom.hex
      end

      def valid_optional_scopes(optional_scopes)
        optional_scopes.to_a & OPTIONAL_SCOPES
      end
    end
  end
end
