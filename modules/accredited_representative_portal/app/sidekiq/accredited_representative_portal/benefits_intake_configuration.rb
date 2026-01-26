# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'faraday/multipart'

module AccreditedRepresentativePortal
  ##
  # HTTP client configuration for the {AccreditedRepresentativePortal::BenefitsIntakeService},
  # sets the base path, the base request headers, and a service name for breakers and metrics.
  #
  class BenefitsIntakeConfiguration < ::BenefitsIntake::Configuration
    self.read_timeout = Settings.accredited_representative_portal.lighthouse.benefits_intake.timeout || 30

    ##
    # @return [Config::Options] Settings for benefits_claims API.
    #
    def intake_settings
      Settings.accredited_representative_portal.lighthouse.benefits_intake
    end

    ##
    # @return [Hash] The basic headers required for any Lighthouse API call
    #
    def self.base_request_headers
      key = Settings.accredited_representative_portal.lighthouse.benefits_intake.api_key
      if key.nil?
        raise 'No api_key set for benefits_intake. Please set ' \
              "'accredited_representative_portal.lighthouse.benefits_intake.api_key'"
      end

      super.merge('apikey' => key)
    end
  end
end
