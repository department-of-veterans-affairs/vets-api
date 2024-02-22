require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'lighthouse/benefits_education/configuration'
require 'lighthouse/service_exception'

module BenefitsEducation
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Concerns::Monitoring

    configuration BenefitsEducation::Configuration

    STATSD_KEY_PREFIX = 'api.benefits_education'

    ##
    # @parameter [String] icn: icn of the Veteran requesting education benefits information
    # @return [BenefitsEducation::Service] a new instance of the service
    #
    def initialize(icn)
      @icn = icn
      raise ArgumentError, 'no ICN passed in for LH API request.' if icn.blank?

      super()
    end

    ##
    # Retrieve a veteran's Post-9/11 GI Bill Status
    # @return [Faraday::Response] response from a GET request to Lighthouse API:
    #   A veteran's GI Bill status
    def get_gi_bill_status
      config.get(@icn)
    rescue => e
      handle_error(e, config.service_name, config.base_api_path)
    end

    def handle_error(error, lighthouse_client_id, endpoint)
      Lighthouse::ServiceException.send_error(
        error,
        self.class.to_s.underscore,
        lighthouse_client_id,
        endpoint
      )
    end
  end
end
