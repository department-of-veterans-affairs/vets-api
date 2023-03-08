# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/direct_deposit/configuration'
require 'lighthouse/direct_deposit/payment_information_response'

module DirectDeposit
  class Service < Common::Client::Base
    configuration DirectDeposit::Configuration
    STATSD_KEY_PREFIX = 'api.direct_deposit'

    def initialize(icn)
      @icn = icn
      raise ArgumentError, 'no ICN passed in for Lighthouse API request.' if icn.blank?

      super()
    end

    def get
      response = config.get("?icn=#{@icn}")
      build_response(response)
    rescue Faraday::ClientError => e
      handle_error(e)
    end

    def update(body)
      response = config.put("?icn=#{@icn}", body)
      build_response(response)
    rescue Faraday::ClientError => e
      handle_error(e)
    end

    def handle_error(e)
      # TODO: log_exception_to_sentry
      Lighthouse::DirectDeposit::PaymentInformationResponse.new(e.response[:status], e.response[:body])
    end

    def build_response(response)
      Lighthouse::DirectDeposit::PaymentInformationResponse.new(response.status, response.body)
    end
  end
end
