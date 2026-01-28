# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'veteran_enrollment_system/form1095_b/configuration'

module VeteranEnrollmentSystem
  module Form1095B
    ##
    # Service class for fetching Form 1095-B data from the enrollment system.
    # This service handles communication with the upstream enrollment system to retrieve
    # Form 1095-B tax forms for users.
    #
    # @example Fetch form data for a specific user and tax year
    #   service = VeteranEnrollmentSystem::Form1095B::Service.new(user)
    #   form_data = service.get_form_by_icn(icn: '1234', tax_year: 2023)
    #
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      configuration VeteranEnrollmentSystem::Form1095B::Configuration

      STATSD_KEY_PREFIX = 'api.form1095b_enrollment'
      ERROR_MAP = {
        400 => Common::Exceptions::BadRequest,
        403 => Common::Exceptions::Forbidden,
        404 => Common::Exceptions::ResourceNotFound,
        500 => Common::Exceptions::ExternalServerInternalServerError,
        502 => Common::Exceptions::BadGateway,
        504 => Common::Exceptions::GatewayTimeout
      }.freeze

      # Fetch Form 1095-B data by ICN and year from the enrollment system
      #
      # @param icn [String] The ICN of the veteran
      # @param tax_year [Integer] The tax year for which to fetch the form
      # @return [Hash] The form data returned by the enrollment system
      # @raise [Common::Exceptions::BackendServiceException] If the upstream service returns an error
      def get_form_by_icn(icn:, tax_year:)
        with_monitoring do
          path = "ves-ee-summary-svc/form1095b/#{icn}/#{tax_year}"
          response = perform(:get, path, {})

          if response.status == 200
            response.body
          else
            raise_error(response, icn)
          end
        end
      end

      private

      def raise_error(response, icn)
        message = if response.body.is_a?(Hash)
                    response.body['messages']&.pluck('description')&.join(', ') || response.body
                  else
                    response.body
                  end
        sanitized_message = message.to_s.gsub(icn, '[REDACTED]')
        raise ERROR_MAP[response.status]&.new(detail: sanitized_message) ||
              Common::Exceptions::BackendServiceException.new(nil, detail: sanitized_message)
      end
    end
  end
end
