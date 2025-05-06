# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'lighthouse/benefits_education/configuration'
require 'lighthouse/service_exception'
require 'lighthouse/benefits_education/response'

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

    # Overriding inspect to avoid displaying icn (now considered to be PII)
    # in the response
    def inspect
      instance_variables_to_inspect = instance_variables - [:@icn]
      instance_variables_string = instance_variables_to_inspect.map do |var|
        "#{var}=#{instance_variable_get(var).inspect}"
      end.join(', ')
      "#<#{self.class}:#{object_id} #{instance_variables_string}>"
    end

    ##
    # Retrieve a veteran's Post-9/11 GI Bill Status
    # @return [String] A JSON string representing the veteran's GI Bill status.
    def get_gi_bill_status
      raw_response = begin
        config.get(@icn)
      rescue Breakers::OutageException => e
        raise e
      rescue => e
        handle_error(e, config.service_name, config.base_path)
      end
      BenefitsEducation::Response.new(raw_response.status, raw_response)
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
