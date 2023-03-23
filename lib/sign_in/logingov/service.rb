# frozen_string_literal: true

require 'sign_in/logingov/configuration'
require 'mockdata/writer'

module SignIn
  module Logingov
    class Service < Common::Client::Base
      configuration Configuration

      SCOPE = 'profile profile:verified_at address email social_security_number openid'

      def render_auth(state: SecureRandom.hex, acr: Constants::Auth::LOGIN_GOV_IAL1)
        Rails.logger.info("[SignIn][Logingov][Service] Rendering auth, state: #{state}, acr: #{acr}")
        RedirectUrlGenerator.new(redirect_uri: auth_url, params_hash: auth_params(acr, state)).perform
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
        response.body
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
          multifactor: true,
          service_name: config.service_name,
          authn_context: get_authn_context(credential_level.current_ial),
          auto_uplevel: credential_level.auto_uplevel
        }
      end

      private

      def auth_params(acr, state)
        {
          acr_values: acr,
          client_id: config.client_id,
          nonce: random_seed,
          prompt: config.prompt,
          redirect_uri: config.redirect_uri,
          response_type: config.response_type,
          scope: SCOPE,
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
    end
  end
end
