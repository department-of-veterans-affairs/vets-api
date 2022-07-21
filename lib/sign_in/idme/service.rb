# frozen_string_literal: true

require 'sign_in/idme/configuration'
require 'sign_in/idme/errors'

module SignIn
  module Idme
    class Service < Common::Client::Base
      configuration SignIn::Idme::Configuration

      attr_accessor :type

      def render_auth(state: SecureRandom.hex, acr: LOA::IDME_LOA1_VETS)
        renderer = ActionController::Base.renderer
        renderer.controller.prepend_view_path(Rails.root.join('lib', 'sign_in', 'templates'))
        renderer.render(template: 'oauth_get_form',
                        locals: {
                          url: auth_url,
                          params:
                          {
                            scope: acr,
                            state: state,
                            client_id: config.client_id,
                            redirect_uri: config.redirect_uri,
                            response_type: config.response_type
                          }
                        },
                        format: :html)
      end

      def normalized_attributes(user_info, credential_level, client_id)
        attributes = case type
                     when 'idme'
                       idme_attributes(user_info)
                     when 'dslogon'
                       dslogon_attributes(user_info)
                     when 'mhv'
                       mhv_attributes(user_info)
                     end
        attributes.merge(standard_attributes(user_info, credential_level, client_id))
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

      def standard_attributes(user_info, credential_level, client_id)
        loa_current = ial_to_loa(credential_level.current_ial)
        loa_highest = ial_to_loa(credential_level.max_ial)
        {
          uuid: user_info.sub,
          idme_uuid: user_info.sub,
          loa: { current: loa_current, highest: loa_highest },
          sign_in: { service_name: get_service_name, auth_broker: SignIn::Constants::Auth::BROKER_CODE,
                     client_id: client_id },
          csp_email: user_info.email,
          multifactor: user_info.multifactor,
          authn_context: get_authn_context(credential_level.current_ial)
        }
      end

      def get_service_name
        type == 'mhv' ? 'myhealthevet' : type
      end

      def get_authn_context(current_ial)
        case type
        when 'idme'
          current_ial == IAL::TWO ? LOA::IDME_LOA3 : LOA::IDME_LOA1_VETS
        when 'dslogon'
          current_ial == IAL::TWO ? LOA::IDME_DSLOGON_LOA3 : LOA::IDME_DSLOGON_LOA1
        when 'mhv'
          current_ial == IAL::TWO ? LOA::IDME_MHV_LOA3 : LOA::IDME_MHV_LOA1
        end
      end

      def idme_attributes(user_info)
        {
          ssn: user_info.social&.tr('-', ''),
          birth_date: user_info.birth_date,
          first_name: user_info.fname,
          last_name: user_info.lname
        }
      end

      def dslogon_attributes(user_info)
        {
          ssn: user_info.dslogon_idvalue&.tr('-', ''),
          birth_date: user_info.dslogon_birth_date,
          first_name: user_info.dslogon_fname,
          middle_name: user_info.dslogon_mname,
          last_name: user_info.dslogon_lname,
          edipi: user_info.dslogon_uuid
        }
      end

      def mhv_attributes(user_info)
        {
          mhv_correlation_id: user_info.mhv_uuid,
          mhv_icn: user_info.mhv_icn
        }
      end

      def ial_to_loa(ial)
        ial == IAL::TWO ? LOA::THREE : LOA::ONE
      end

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
