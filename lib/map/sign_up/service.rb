# frozen_string_literal: true

require 'map/sign_up/configuration'
require 'map/security_token/service'

module MAP
  module SignUp
    class Service < Common::Client::Base
      configuration Configuration

      def status(icn:)
        response = perform(:get, config.status_unauthenticated_path(icn), nil)
        logger.info("#{logging_prefix} status success, icn: #{icn}")
        build_response(response.body)
      rescue Common::Client::Errors::ParsingError => e
        message = "#{logging_prefix} status response parsing error"
        logger.error(message, { icn: })
        raise e, "#{message}, response unknown, icn: #{icn}"
      rescue Common::Client::Errors::ClientError => e
        parse_and_raise_error(e, icn, 'status')
      end

      def agreements_accept(icn:, signature_name:, version:)
        perform(:post,
                config.patients_agreements_path(icn),
                agreements_body(icn, signature_name, version),
                authenticated_header(icn))
        logger.info("#{logging_prefix} agreements accept success, icn: #{icn}")
      rescue Common::Client::Errors::ParsingError => e
        message = "#{logging_prefix} agreements accept response parsing error"
        logger.error(message, { icn: })
        raise e, "#{message}, response unknown, icn: #{icn}"
      rescue Common::Client::Errors::ClientError => e
        parse_and_raise_error(e, icn, 'agreements accept')
      end

      def agreements_decline(icn:)
        perform(:delete, config.patients_agreements_path(icn), nil, authenticated_header(icn))
        logger.info("#{logging_prefix} agreements decline success, icn: #{icn}")
      rescue Common::Client::Errors::ParsingError => e
        message = "#{logging_prefix} agreements decline response parsing error"
        logger.error(message, { icn: })
        raise e, "#{message}, response unknown, icn: #{icn}"
      rescue Common::Client::Errors::ClientError => e
        parse_and_raise_error(e, icn, 'agreements decline')
      end

      def update_provisioning(icn:, first_name:, last_name:, mpi_gcids:)
        response = perform(:put,
                           config.patients_provisioning_path(icn),
                           update_provisioning_params(first_name, last_name, mpi_gcids).to_json,
                           config.authenticated_provisioning_header)
        successful_update_provisioning_response(response, icn)
      rescue Common::Client::Errors::ParsingError => e
        message = "#{logging_prefix} update provisioning response parsing error"
        logger.error(message, { icn: })
        raise e, "#{message}, response unknown, icn: #{icn}"
      rescue Common::Client::Errors::ClientError => e
        if config.provisioning_acceptable_status.include?(e.status)
          successful_update_provisioning_response(e, icn)
        else
          parse_and_raise_error(e, icn, 'update provisioning')
        end
      end

      private

      def authenticated_header(icn)
        access_token = SecurityToken::Service.new.token(application: :sign_up_service, icn:)
        config.authenticated_header(access_token[:access_token])
      end

      def agreements_body(icn, signature_name, version)
        {
          responseDate: Time.zone.now,
          icn:,
          signatureName: signature_name,
          version: config.agreements_version_mapping[version],
          legalDisplayVersion: config.legal_display_version
        }.to_json
      end

      def update_provisioning_params(first_name, last_name, mpi_gcids)
        {
          provisionUser: true,
          gcids: mpi_gcids,
          firstName: first_name,
          lastName: last_name
        }
      end

      def successful_update_provisioning_response(response, icn)
        parsed_response = build_response(response.body)

        logger.info("#{logging_prefix} update provisioning success," \
                    " icn: #{icn}, parsed_response: #{parsed_response}")

        parsed_response
      end

      def parse_and_raise_error(e, icn, action)
        status = e.status
        parsed_body = e.body.presence || {}
        context = {
          id: parsed_body['id'],
          code: parsed_body['code'],
          error_code: parsed_body['errorCode'],
          message: parsed_body['message'],
          trace_id: parsed_body['traceId']
        }.compact
        raise e, "#{logging_prefix} #{action} failed, client error, status: #{status}," \
                 " icn: #{icn}, context: #{context}"
      end

      def build_response(response_body)
        {
          agreement_signed: response_body['agreementSigned'],
          opt_out: response_body['optOut'],
          cerner_provisioned: response_body['cernerProvisioned'],
          bypass_eligible: response_body['bypassEligible']
        }
      end

      def logger
        Rails.logger
      end

      def logging_prefix
        config.logging_prefix
      end
    end
  end
end
