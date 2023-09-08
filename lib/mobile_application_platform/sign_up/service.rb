# frozen_string_literal: true

require 'mobile_application_platform/sign_up/configuration'
require 'mobile_application_platform/security_token/service'

module MobileApplicationPlatform
  module SignUp
    class Service < Common::Client::Base
      configuration Configuration

      def status(icn:)
        response = perform(:get, config.status_unauthenticated_path(icn), nil)
        Rails.logger.info("#{config.logging_prefix} status success, icn: #{icn}")
        parse_response(response, icn, 'status')
      rescue Common::Client::Errors::ClientError => e
        status = e.status
        description = e.body.presence && e.body[:error_description]
        raise e, "#{config.logging_prefix} status failed, client error, status: #{status}," \
                 " description: #{description}, icn: #{icn}"
      end

      def agreements_accept(icn:)
        perform(:post, config.patients_agreements_path(icn), '', authenticated_header(icn))
        Rails.logger.info("#{config.logging_prefix} agreements accept success, icn: #{icn}")
      rescue Common::Client::Errors::ClientError => e
        status = e.status
        description = e.body.presence && e.body[:error_description]
        raise e, "#{config.logging_prefix} agreements accept failed, client error, status: #{status}," \
                 " description: #{description}, icn: #{icn}"
      end

      def agreements_decline(icn:)
        perform(:delete, config.patients_agreements_path(icn), nil, authenticated_header(icn))
        Rails.logger.info("#{config.logging_prefix} agreements decline success, icn: #{icn}")
      rescue Common::Client::Errors::ClientError => e
        status = e.status
        description = e.body.presence && e.body[:error_description]
        raise e, "#{config.logging_prefix} agreements decline failed, client error, status: #{status}," \
                 " description: #{description}, icn: #{icn}"
      end

      def update_provisioning(icn:, first_name:, last_name:, mpi_gcids:)
        response = perform(:put,
                           config.patients_provisioning_path(icn),
                           update_provisioning_params(first_name, last_name, mpi_gcids).to_json,
                           config.authenticated_provisioning_header)
        Rails.logger.info("#{config.logging_prefix} update provisioning success, icn: #{icn}")
        parse_response(response, icn, 'update provisioning')
      rescue Common::Client::Errors::ClientError => e
        status = e.status
        description = e.body.presence && e.body[:error_description]
        raise e, "#{config.logging_prefix} update provisioning failed, client error, status: #{status}," \
                 " description: #{description}, icn: #{icn}"
      end

      private

      def authenticated_header(icn)
        access_token = SecurityToken::Service.new.token(application: :sign_up_service, icn:)
        config.authenticated_header(access_token[:access_token])
      end

      def update_provisioning_params(first_name, last_name, mpi_gcids)
        {
          provisionUser: true,
          gcids: mpi_gcids,
          firstName: first_name,
          lastName: last_name
        }
      end

      def parse_response(response, icn, action)
        response_body = JSON.parse(response.body)

        {
          agreement_signed: response_body['agreementSigned'],
          opt_out: response_body['optOut'],
          cerner_provisioned: response_body['cernerProvisioned'],
          bypass_eligible: response_body['bypassEligible']
        }
      rescue => e
        raise e, "#{config.logging_prefix} #{action} failed, response unknown, icn: #{icn}"
      end
    end
  end
end
