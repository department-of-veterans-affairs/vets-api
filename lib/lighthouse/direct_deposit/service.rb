# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/direct_deposit/configuration'
require 'lighthouse/direct_deposit/financial_institution'
require 'lighthouse/direct_deposit/response'

module DirectDeposit
  class Service < Common::Client::Base
    configuration DirectDeposit::Configuration
    STATSD_KEY_PREFIX = 'api.direct_deposit'

    def initialize(icn)
      @icn = icn
      raise ArgumentError, 'no ICN passed in for Lighthouse API request.' if icn.blank?

      super()
    end

    def get_direct_deposits
      response = config.get("?icn=#{@icn}")
      build_response(response)
    rescue Faraday::ClientError => e
      handle_error(e)
    end

    def update_direct_deposit(body)
      response = config.put("?icn=#{@icn}", body)
      build_response(response)
    rescue Faraday::ClientError => e
      handle_error(e)
    end

    def handle_error(e)
      # TODO: log_exception_to_sentry

      status = e.response[:status]
      body = e.response[:body]

      Lighthouse::DirectDeposit::Response.new(status, body)
    end

    def build_response(response)
      Lighthouse::DirectDeposit::Response.new(response.status, response.body)
    end
  end
end
