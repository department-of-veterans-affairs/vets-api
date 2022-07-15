# frozen_string_literal: true

require 'sign_in/logingov/configuration'

module SignIn
  module Logingov
    class Service < Common::Client::Base
      configuration SignIn::Logingov::Configuration

      SCOPE = 'profile profile:verified_at address email social_security_number openid'

      def render_auth(state: SecureRandom.hex, acr: IAL::LOGIN_GOV_IAL1)
        renderer = ActionController::Base.renderer
        renderer.controller.prepend_view_path(Rails.root.join('lib', 'sign_in', 'templates'))
        renderer.render(template: 'oauth_get_form',
                        locals: {
                          url: auth_url,
                          params:
                          {
                            acr_values: acr,
                            client_id: config.client_id,
                            nonce: nonce,
                            prompt: config.prompt,
                            redirect_uri: config.redirect_uri,
                            response_type: config.response_type,
                            scope: SCOPE,
                            state: state
                          }
                        },
                        format: :html)
      end

      def render_logout(id_token:)
        "#{sign_out_url}?#{sign_out_params(id_token, config.logout_redirect_uri, SecureRandom.hex).to_query}"
      end

      def token(code)
        response = perform(
          :post, config.token_path, token_params(code), { 'Content-Type' => 'application/json' }
        )
        response.body
      rescue Common::Client::Errors::ClientError => e
        raise e
      end

      def user_info(token)
        response = perform(:get, config.userinfo_path, nil, { 'Authorization' => "Bearer #{token}" })
        response.body
      rescue Common::Client::Errors::ClientError => e
        raise e
      end

      def normalized_attributes(user_info, credential_level, client_id)
        loa_current = ial_to_loa(credential_level.current_ial)
        loa_highest = ial_to_loa(credential_level.max_ial)
        {
          uuid: user_info[:sub],
          logingov_uuid: user_info[:sub],
          loa: { current: loa_current, highest: loa_highest },
          ssn: user_info[:social_security_number]&.tr('-', ''),
          birth_date: user_info[:birthdate],
          first_name: user_info[:given_name],
          last_name: user_info[:family_name],
          csp_email: user_info[:email],
          sign_in: { service_name: config.service_name, auth_broker: SignIn::Constants::Auth::BROKER_CODE,
                     client_id: client_id },
          authn_context: get_authn_context(credential_level.current_ial)
        }
      end

      private

      def get_authn_context(current_ial)
        current_ial == IAL::TWO ? IAL::LOGIN_GOV_IAL2 : IAL::LOGIN_GOV_IAL1
      end

      def ial_to_loa(ial)
        ial == IAL::TWO ? LOA::THREE : LOA::ONE
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

      def sign_out_params(id_token, redirect_uri, state)
        {
          id_token_hint: id_token,
          post_logout_redirect_uri: redirect_uri,
          state: state
        }
      end

      def token_params(code)
        {
          grant_type: config.grant_type,
          code: code,
          client_assertion_type: config.client_assertion_type,
          client_assertion: client_assertion_jwt
        }.to_json
      end

      def client_assertion_jwt
        jwt_payload = {
          iss: config.client_id,
          sub: config.client_id,
          aud: token_url,
          jti: SecureRandom.hex,
          nonce: nonce,
          exp: Time.now.to_i + config.client_assertion_expiration_seconds
        }
        JWT.encode(jwt_payload, config.ssl_key, 'RS256')
      end

      def nonce
        @nonce ||= SecureRandom.hex
      end
    end
  end
end
