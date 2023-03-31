# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/direct_deposit/configuration'
require 'lighthouse/direct_deposit/payment_information'
require 'lighthouse/direct_deposit/error'

module DirectDeposit
  class Client < Common::Client::Base
    include SentryLogging
    configuration DirectDeposit::Configuration
    STATSD_KEY_PREFIX = 'api.direct_deposit'

    def initialize(icn)
      @icn = icn
      raise ArgumentError, 'no ICN passed in for Lighthouse API request.' if icn.blank?

      super()
    end

    def get_payment_information
      response = config.get("?icn=#{@icn}")
      parse_response(response)
    end

    def update(body)
      response = config.put("?icn=#{@icn}", body)
      parse_response(response)
    end

    private

    def valid_response?(response)
      ok?(response) || control_info?(response)
    end

    def ok?(response)
      response.status.between?(200, 299)
    end

    def control_info?(response)
      response.body['controlInformation'].present?
    end

    def parse_response(response)
      if valid_response?(response)
        Lighthouse::DirectDeposit::PaymentInformation.build_from(response)
      else
        error = Lighthouse::DirectDeposit::Error.new(response)
        log_message_to_sentry(error.title, :error, body: error.body)
        error
      end
    end
  end
end
