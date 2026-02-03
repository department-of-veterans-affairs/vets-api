# frozen_string_literal: true

require 'sign_in/public_jwks'
require 'sign_in/idme/configuration'
require 'sign_in/idme/errors'
require 'sign_in/credential_attributes_digester'
require 'mockdata/writer'

module SignIn
  module Idme
    class Service < Common::Client::Base
      include SignIn::PublicJwks
      configuration Configuration

      OPTIONAL_SCOPES = [ALL_EMAILS_SCOPE = 'all_emails'].freeze

      attr_accessor :type, :optional_scopes

      def initialize(type:, optional_scopes: [])
        @type = type
        @optional_scopes = valid_optional_scopes(optional_scopes)
        super()
      end

      def render_auth(state: SecureRandom.hex,
                      acr: { acr: Constants::Auth::IDME_LOA1 },
                      operation: Constants::Auth::AUTHORIZE)
        scoped_acr = append_optional_scopes(acr[:acr])
        Rails.logger.info('[SignIn][Idme][Service] Rendering auth, ' \
                          "state: #{state}, acr: #{scoped_acr}, operation: #{operation}")

        RedirectUrlGenerator.new(redirect_uri: auth_url,
                                 params_hash: auth_params(scoped_acr, acr[:acr_comparison], state, operation)).perform
      end

      def normalized_attributes(user_info, credential_level)
        attributes = case type
                     when Constants::Auth::IDME
                       idme_attributes(user_info)
                     when Constants::Auth::MHV
                       mhv_attributes(user_info)
                     end

        attributes.merge(standard_attributes(user_info, credential_level)).tap do |attrs|
          attrs[:digest] = credential_attributes_digest(attrs)
        end
      end

      def token(code)
        response = perform(
          :post, config.token_path, token_params(code), { 'Content-Type' => 'application/json' }
        )
        Rails.logger.info("[SignIn][Idme][Service] Token Success, code: #{code}, scope: #{response.body[:scope]}")
        response.body
      rescue Common::Client::Errors::ClientError => e
        raise_client_error(e, 'Token')
      end

      def user_info(token)
        response = perform(:get, config.userinfo_path, nil, { 'Authorization' => "Bearer #{token}" })
        decrypted_jwe = jwe_decrypt(JSON.parse(response.body))
        jwt_decode(decrypted_jwe)
      rescue Common::Client::Errors::ClientError => e
        raise_client_error(e, 'UserInfo')
      end

      private

      def auth_params(acr, acr_comparison, state, operation)
        {
          scope: acr,
          state:,
          client_id: config.client_id,
          redirect_uri: config.redirect_uri,
          response_type: config.response_type,
          acr_values: format_acr_comparison(acr_comparison),
          op: convert_operation(operation)
        }.compact
      end

      def format_acr_comparison(acr_comparison)
        acr_comparison ? "#{acr_comparison} #{Constants::Auth::IDME_LOA1}" : nil
      end

      def convert_operation(operation)
        case operation
        when Constants::Auth::SIGN_UP
          config.sign_up_operation
        end
      end

      def raise_client_error(client_error, function_name)
        status = client_error.status
        description = client_error.body && client_error.body[:error_description]
        raise client_error, "[SignIn][Idme][Service] Cannot perform #{function_name} request, " \
                            "status: #{status}, description: #{description}"
      end

      def standard_attributes(user_info, credential_level)
        {
          idme_uuid: user_info.sub,
          current_ial: credential_level.current_ial,
          max_ial: credential_level.max_ial,
          service_name: type,
          csp_email: user_info.email,
          all_csp_emails: user_info.emails_confirmed,
          multifactor: user_info.multifactor,
          authn_context: get_authn_context(credential_level.current_ial),
          auto_uplevel: credential_level.auto_uplevel
        }
      end

      def get_authn_context(current_ial)
        case type
        when Constants::Auth::IDME
          current_ial == Constants::Auth::IAL_TWO ? Constants::Auth::IDME_LOA3 : Constants::Auth::IDME_LOA1
        when Constants::Auth::MHV
          current_ial == Constants::Auth::IAL_TWO ? Constants::Auth::IDME_MHV_LOA3 : Constants::Auth::IDME_MHV_LOA1
        end
      end

      def idme_attributes(user_info)
        {
          ssn: user_info.social&.tr('-', ''),
          birth_date: user_info.birth_date,
          first_name: user_info.fname,
          last_name: user_info.lname,
          address: normalize_address(user_info)
        }
      end

      def mhv_attributes(user_info)
        {
          mhv_credential_uuid: user_info.mhv_uuid,
          mhv_icn: user_info.mhv_icn,
          mhv_assurance: user_info.mhv_assurance
        }
      end

      def normalize_address(user_info)
        return unless address_defined?(user_info)

        {
          street: user_info.street,
          postal_code: user_info.zip,
          state: user_info.state,
          city: user_info.city,
          country: united_states_country_code
        }
      end

      def address_defined?(user_info)
        user_info.street && user_info.zip && user_info.state && user_info.city
      end

      def united_states_country_code
        'USA'
      end

      def jwe_decrypt(encrypted_jwe)
        JWE.decrypt(encrypted_jwe, config.ssl_key)
      rescue JWE::DecodeError
        raise Errors::JWEDecodeError, '[SignIn][Idme][Service] JWE is malformed'
      end

      def jwt_decode(encoded_jwt)
        verify_expiration = true

        decoded_jwt = JWT.decode(
          encoded_jwt,
          nil,
          verify_expiration,
          { verify_expiration:, algorithm: config.jwt_decode_algorithm, jwks: method(:jwks_loader) }
        ).first
        log_parsed_credential(decoded_jwt) if config.log_credential

        parse_decoded_jwt(decoded_jwt)
      rescue JWT::JWKError
        raise Errors::PublicJWKError, '[SignIn][Idme][Service] Public JWK is malformed'
      rescue JWT::VerificationError
        raise Errors::JWTVerificationError, '[SignIn][Idme][Service] JWT body does not match signature'
      rescue JWT::ExpiredSignature
        raise Errors::JWTExpiredError, '[SignIn][Idme][Service] JWT has expired'
      rescue JWT::DecodeError
        raise Errors::JWTDecodeError, '[SignIn][Idme][Service] JWT is malformed'
      end

      def parse_decoded_jwt(decoded_jwt)
        jwt_struct = OpenStruct.new(decoded_jwt)
        jwt_struct.level_of_assurance ||= jwt_struct.lname ? Constants::Auth::LOA_THREE : Constants::Auth::LOA_ONE
        jwt_struct.credential_ial ||= jwt_struct.lname ? Constants::Auth::IAL_TWO : Constants::Auth::IAL_ONE
        jwt_struct
      end

      def log_parsed_credential(decoded_jwt)
        MockedAuthentication::Mockdata::Writer.save_credential(credential: decoded_jwt, credential_type: type)
      end

      def auth_url
        "#{config.base_path}/#{config.auth_path}"
      end

      def token_params(code)
        {
          grant_type: config.grant_type,
          code:,
          client_id: config.client_id,
          client_secret: config.client_secret,
          redirect_uri: config.redirect_uri
        }.to_json
      end

      def append_optional_scopes(acr)
        return acr unless optional_scopes.any? && acr == Constants::Auth::IDME_LOA3_FORCE

        "#{acr}/#{optional_scopes.join('/')}"
      end

      def valid_optional_scopes(optional_scopes)
        optional_scopes.to_a & OPTIONAL_SCOPES
      end

      def credential_attributes_digest(attributes)
        SignIn::CredentialAttributesDigester.new(credential_uuid: attributes[:idme_uuid],
                                                 first_name: attributes[:first_name],
                                                 last_name: attributes[:last_name],
                                                 ssn: attributes[:ssn],
                                                 birth_date: attributes[:birth_date],
                                                 email: attributes[:csp_email]).perform
      end
    end
  end
end
