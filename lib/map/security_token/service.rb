# frozen_string_literal: true

require 'map/security_token/configuration'
require 'map/security_token/errors'

module MAP
  module SecurityToken
    class Service < Common::Client::Base
      configuration Configuration

      def token(application:, icn:)
        response = perform(:post,
                           config.token_path,
                           token_params(application, icn),
                           { 'Content-Type' => 'application/x-www-form-urlencoded' })
        Rails.logger.info("#{config.logging_prefix} token success, application: #{application}, icn: #{icn}")
        parse_response(response, application, icn)
      rescue Common::Client::Errors::ClientError => e
        parse_and_raise_error(e, icn, application)
      end

      private

      def parse_and_raise_error(e, icn, application)
        status = e.status
        parse_body = e.body.present? ? JSON.parse(e.body) : {}
        context = { error: parse_body['error'] }
        raise e, "#{config.logging_prefix} token failed, client error, status: #{status}," \
                 " application: #{application}, icn: #{icn}, context: #{context}"
      end

      def parse_response(response, application, icn)
        response_body = JSON.parse(response.body)

        {
          access_token: response_body['access_token'],
          expiration: Time.zone.now + response_body['expires_in']
        }
      rescue => e
        raise e, "#{config.logging_prefix} token failed, response unknown, application: #{application}, icn: #{icn}"
      end

      def client_id_from_application(application)
        case application
        when :chatbot
          config.chatbot_client_id
        when :sign_up_service
          config.sign_up_service_client_id
        when :check_in
          config.check_in_client_id
        else
          raise Errors::ApplicationMismatchError, "#{config.logging_prefix} application mismatch detected"
        end
      end

      def token_params(application, icn)
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
