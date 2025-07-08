# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'veteran_enrollment_system/form1095_b/configuration'

module VeteranEnrollmentSystem
  module Form1095B
    ##
    # Service class for fetching Form 1095-B data from the enrollment system.
    # This service handles communication with the upstream enrollment system to retrieve
    # Form 1095-B tax forms for veterans.
    #
    # @example Fetch form data for a specific user and tax year
    #   service = VeteranEnrollmentSystem::Form1095B::Service.new(user)
    #   form_data = service.get_form_by_icn(icn: '1234', tax_year: 2023)
    #
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring
      include SentryLogging

      configuration VeteranEnrollmentSystem::Form1095B::Configuration
      STATSD_KEY_PREFIX = 'api.form1095b_enrollment'

      # @param user [User] The user for whom to fetch Form 1095-B data
      def initialize(user = nil)
        @user = user
        super()
      end

      # Fetch Form 1095-B data by ICN from the enrollment system
      #
      # @param icn [String] The ICN of the veteran
      # @param tax_year [Integer] The tax year for which to fetch the form
      # @return [Hash] The form data returned by the enrollment system
      # @raise [Common::Exceptions::BackendServiceException] If the upstream service returns an error
      def get_form_by_icn(icn:, tax_year:)
        with_monitoring do
          response = perform(:get, form_by_icn_path(tax_year, icn), nil, request_headers)
          response.body
        end
      rescue Faraday::Error => e
        handle_error(e)
      end

      private

      def form_by_icn_path(tax_year, icn)
        "form1095b/#{icn}/#{tax_year}"
      end

      def request_headers
        headers = {}

        if @user.present?
          headers['X-VA-ICN'] = @user.icn if @user.icn.present?
          headers['X-VA-SSN'] = @user.ssn if @user.ssn.present?
        end

        headers
      end

      def handle_error(error)
        if error.is_a?(Faraday::ParsingError)
          log_message_to_sentry('Form 1095B enrollment invalid JSON response', :error)
          raise_backend_exception('ENROLLMENT_SYSTEM_PARSING_ERROR', self.class)
        elsif error.is_a?(Faraday::TimeoutError)
          log_message_to_sentry('Form 1095B enrollment timeout', :error)
          raise_backend_exception('GATEWAY_TIMEOUT', self.class)
        elsif error.is_a?(Faraday::ClientError)
          response_hash = error.response&.to_hash
          response_body = response_hash&.dig(:body)

          log_message_to_sentry('Form 1095B enrollment service returned error', :error,
                              { response_body: response_body })

          raise_backend_exception("ENROLLMENT_#{error.response&.fetch(:status, 500)}",
                                self.class, error)
        else
          log_exception_to_sentry(error)
          raise_backend_exception('ENROLLMENT_SYSTEM_ERROR', self.class, error)
        end
      end

      def raise_backend_exception(key, source, error = nil)
        exception = Common::Exceptions::BackendServiceException.new(
          key,
          { source: source.to_s },
          error&.try(:response)&.try(:status),
          error&.try(:response)&.try(:body)
        )
        raise exception
      end
    end
  end
end