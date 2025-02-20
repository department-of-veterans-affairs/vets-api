# frozen_string_literal: true

require 'map/security_token/configuration'
require 'map/security_token/errors'
require 'sign_in/public_jwks'

module MAP
  module SecurityToken
    class Service < Common::Client::Base
      include SignIn::PublicJwks
      configuration Configuration

      def token(application:, icn:, cache: true)
        cached_response = true
        Rails.logger.info("#{config.log_prefix} token request", { application:, icn: })
        token = Rails.cache.fetch("map_sts_token_#{application}_#{icn}", expires_in: 5.minutes, force: !cache) do
          cached_response = false
          request_token(application, icn)
        end
        Rails.logger.info("#{config.log_prefix} token success", { application:, icn:, cached_response: })
        token
      rescue Common::Client::Errors::ParsingError => e
        Rails.logger.error("#{config.log_prefix} token failed, parsing error", application:, icn:,
                                                                               context: e.message)
        raise e
      rescue JWT::DecodeError => e
        Rails.logger.error("#{config.log_prefix} token failed, JWT decode error", application:, icn:,
                                                                                  context: e.message)
        raise e
      rescue Common::Client::Errors::ClientError => e
        parse_and_raise_error(e, icn, application)
      rescue Common::Exceptions::GatewayTimeout => e
        Rails.logger.error("#{config.log_prefix} token failed, gateway timeout", application:, icn:)
        raise e
      rescue Errors::ApplicationMismatchError => e
        Rails.logger.error(e.message, application:, icn:)
        raise e
      rescue Errors::MissingICNError => e
        Rails.logger.error(e.message, application:)
        raise e
      end

      private

      def request_token(application, icn)
        response = perform(:post,
                           config.token_path,
                           token_params(application, icn),
                           { 'Content-Type' => 'application/x-www-form-urlencoded' })
        parse_response(response, application, icn)
      end

      def parse_and_raise_error(e, icn, application)
        status = e.status
        error_source = status >= 500 ? 'server' : 'client'
        parse_body = e.body.presence || {}
        context = { error: parse_body['error'] }
        message = "#{config.log_prefix} token failed, #{error_source} error"

        Rails.logger.error(message, status:, application:, icn:, context:)
        raise e, "#{message}, status: #{status}, application: #{application}, icn: #{icn}, context: #{context}"
      end

      def parse_response(response, application, icn)
        response_body = response.body
        validate_map_token(response_body['access_token'])

        {
          access_token: response_body['access_token'],
          expiration: Time.zone.now + response_body['expires_in']
        }
      rescue JWT::DecodeError => e
        raise e
      rescue => e
        message = "#{config.log_prefix} token failed, response unknown"
        Rails.logger.error(message, application:, icn:)
        raise e, "#{message}, application: #{application}, icn: #{icn}"
      end

      def validate_map_token(encoded_token)
        public_keys = public_jwks.keys.map(&:public_key)
        JWT.decode(encoded_token, public_keys, true, { algorithms: ['RS512'] })
      end

      def client_id_from_application(application)
        case application
        when :chatbot
          config.chatbot_client_id
        when :sign_up_service
          config.sign_up_service_client_id
        when :check_in
          config.check_in_client_id
        when :appointments
          config.appointments_client_id
        else
          raise Errors::ApplicationMismatchError, "#{config.log_prefix} token failed, application mismatch detected"
        end
      end

      def token_params(application, icn)
        raise Errors::MissingICNError, "#{config.log_prefix} token failed, ICN not present in access token" unless icn

        client_id = client_id_from_application(application)
        URI.encode_www_form({ grant_type: config.grant_type,
                              client_id:,
                              client_assertion_type: config.client_assertion_type,
                              client_assertion: client_assertion_jwt(client_id, icn) })
      end

      def client_assertion_jwt_payload(client_id, icn)
        {
          role: config.client_assertion_role,
          patient_id: icn,
          patient_id_type: config.client_assertion_patient_id_type,
          sub: client_id,
          jti: client_assertion_jti_seed,
          iss: client_id,
          aud: "#{config.base_path}/#{config.token_path}",
          nbf: client_assertion_creation_time.to_i,
          exp: client_assertion_expiration.to_i
        }
      end

      def client_assertion_jwt(client_id, icn)
        JWT.encode(client_assertion_jwt_payload(client_id, icn),
                   config.client_assertion_private_key,
                   config.client_assertion_encode_algorithm)
      end

      def client_assertion_jti_seed
        SecureRandom.uuid
      end

      def client_assertion_creation_time
        Time.zone.now
      end

      def client_assertion_expiration
        (client_assertion_creation_time + config.client_assertion_expiration_seconds)
      end
    end
  end
end
