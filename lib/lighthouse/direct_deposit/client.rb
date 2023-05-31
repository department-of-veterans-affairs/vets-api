# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/direct_deposit/configuration'
require 'lighthouse/direct_deposit/payment_info_parser'
require 'lighthouse/service_exception'

module DirectDeposit
  class Client < Common::Client::Base
    configuration DirectDeposit::Configuration
    STATSD_KEY_PREFIX = 'api.direct_deposit'

    def initialize(icn)
      @icn = icn
      raise ArgumentError, 'no ICN passed in for Lighthouse API request.' if icn.blank?

      super()
    end

    def get_payment_info
      response = config.get("?icn=#{@icn}")
      handle_response(response)
    rescue Faraday::ClientError, Faraday::ServerError => e
      handle_error(e, config.settings.client_id, config.base_path)
    end

    def update_payment_info(params)
      body = build_request_body(params)

      response = config.put("?icn=#{@icn}", body)
      handle_response(response)
    rescue Faraday::ClientError, Faraday::ServerError => e
      handle_error(e, config.settings.client_id, config.base_path)
    end

    private

    def handle_response(response)
      Lighthouse::DirectDeposit::PaymentInfoParser.parse(response)
    end

    def handle_error(error, lighthouse_client_id, base_path)
      Lighthouse::ServiceException.send_error(
        error,
        self.class.to_s.underscore,
        lighthouse_client_id,
        base_path
      )
    end

    def build_request_body(payment_account)
      {
        'paymentAccount' =>
        {
          'accountNumber' => payment_account.account_number,
          'accountType' => payment_account.account_type,
          'financialInstitutionRoutingNumber' => payment_account.routing_number
        }
      }.to_json
    end
  end
end
