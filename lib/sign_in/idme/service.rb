# frozen_string_literal: true

require 'sign_in/idme/configuration'
require 'sign_in/idme/errors'

module SignIn
  module Idme
    class Service < Common::Client::Base
      configuration SignIn::Idme::Configuration

      attr_accessor :type

      def render_auth(state: SecureRandom.hex)
        renderer = ActionController::Base.renderer
        renderer.controller.prepend_view_path(Rails.root.join('lib', 'sign_in', 'templates'))
        renderer.render(template: 'oauth_get_form',
                        locals: {
                          url: auth_url,
                          params:
                          {
                            scope: scope,
                            state: state,
                            client_id: config.client_id,
                            redirect_uri: config.redirect_uri,
                            response_type: config.response_type
                          }
                        },
                        format: :html)
      end

      def normalized_attributes(user_info)
        {
          uuid: user_info.sub,
          idme_uuid: user_info.sub,
          loa: { current: user_info.level_of_assurance, highest: user_info.level_of_assurance },
          ssn: user_info.social&.tr('-', ''),
          birth_date: user_info.birth_date,
          first_name: user_info.fname,
          last_name: user_info.lname,
          email: user_info.email,
          sign_in: { service_name: config.service_name },
          authn_context: type
        }
      end

      def token(code)
        response = perform(
          :post, config.token_path, token_params(code), { 'Content-Type' => 'application/json' }
        )
        response.body
      rescue Common::Client::Errors::ClientError => e
        raise e, 'Cannot perform Token request'
      end

      def user_info(token)
        response = perform(:get, config.userinfo_path, nil, { 'Authorization' => "Bearer #{token}" })
        decrypted_jwe = jwe_decrypt(JSON.parse(response.body))
        jwt_decode(decrypted_jwe)
      rescue Common::Client::Errors::ClientError => e
        raise e, 'Cannot perform UserInfo request'
      end

      private

      def scope
        case type
        when 'idme'
          config.idme_scope
        when 'dslogon'
          config.dslogon_scope
        when 'mhv'
          config.mhv_scope
        end
      end

      def jwe_decrypt(encrypted_jwe)
        JWE.decrypt(encrypted_jwe, config.ssl_key)
      rescue JWE::DecodeError
        raise Errors::JWEDecodeError, 'JWE is malformed'
      end

      def jwt_decode(encoded_jwt)
        with_validation = true
        decoded_jwt = JWT.decode(
          encoded_jwt,
          config.jwt_decode_public_key,
          with_validation,
          {
            verify_expiration: with_validation,
            algorithm: config.jwt_decode_algorithm
          }
        )&.first
        OpenStruct.new(decoded_jwt)
      rescue JWT::VerificationError
        raise Errors::JWTVerificationError, 'JWT body does not match signature'
      rescue JWT::ExpiredSignature
        raise Errors::JWTExpiredError, 'JWT has expired'
      rescue JWT::DecodeError
        raise Errors::JWTDecodeError, 'JWT is malformed'
      end

      def auth_url
        "#{config.base_path}/#{config.auth_path}"
      end

      def token_params(code)
        {
          grant_type: config.grant_type,
          code: code,
          client_id: config.client_id,
          client_secret: config.client_secret,
          redirect_uri: config.redirect_uri
        }.to_json
      end
    end
  end
end
