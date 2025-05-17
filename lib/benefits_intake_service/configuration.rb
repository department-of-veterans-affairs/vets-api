# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'faraday/multipart'
require 'lighthouse/benefits_intake/configuration'

module BenefitsIntakeService
  ##
  # Configuration for the Benefits Intake Service.
  #
  # @deprecated Please use BenefitsIntake::Configuration instead
  # This class is maintained for backward compatibility but will be removed in the future.
  #
  class Configuration < Common::Client::Configuration::REST
    def initialize
      ActiveSupport::Deprecation.new.warn(
        'BenefitsIntakeService::Configuration is deprecated. ' \
        'Please use BenefitsIntake::Configuration instead.'
      )
      super
      # Set fallback settings if needed
      Settings.benefits_intake_service.api_key ||= Settings.form526_backup.api_key
      Settings.benefits_intake_service.url ||= Settings.form526_backup.url
    end

    # Use the same timeout as the Lighthouse implementation
    self.read_timeout = Settings.caseflow.timeout || 20

    ##
    # @return [String] Base path
    #
    def base_path
      Settings.benefits_intake_service.url
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'BenefitsIntakeService'
    end

    ##
    # @return [Hash] The basic headers required for any Lighthouse API call
    #
    def self.base_request_headers
      super.merge('apikey' => Settings.benefits_intake_service.api_key)
    end

    ##
    # Creates a connection with json parsing and breaker functionality.
    # Delegates to the Lighthouse implementation while maintaining compatibility with
    # the original BenefitsIntakeService settings.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      # Override Lighthouse settings temporarily to use our settings
      original_api_key = Settings.lighthouse.benefits_intake.api_key
      original_url = Settings.lighthouse.benefits_intake.host

      begin
        # Use our settings for the Lighthouse connection
        Settings.lighthouse.benefits_intake.api_key = Settings.benefits_intake_service.api_key
        Settings.lighthouse.benefits_intake.host = Settings.benefits_intake_service.url

        lighthouse_service = BenefitsIntake::Service.new
        lighthouse_service.send(:connection)
      ensure
        # Restore original settings
        Settings.lighthouse.benefits_intake.api_key = original_api_key
        Settings.lighthouse.benefits_intake.host = original_url
      end
    end

    ##
    # @return [Boolean] Should the service use mock data in lower environments.
    #
    def mock_enabled?
      Settings.benefits_intake_service.mock || false
    end

    def breakers_error_threshold
      80 # breakers will be tripped if error rate reaches 80% over a two minute period.
    end
  end
end
