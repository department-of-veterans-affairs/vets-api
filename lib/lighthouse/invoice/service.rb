# frozen_string_literal: true

require 'lighthouse/invoice/configuration'
require 'lighthouse/service_exception'
require 'common/exceptions/bad_request'

module Invoice
  class Service < Common::Client::Base
    configuration Lighthouse::Invoice::Configuration
    STATSD_KEY_PREFIX = 'api.lighthouse.invoice'

    def initialize(current_user)
      @current_user = current_user
      super()
    end

    def get_invoice
      endpoint = 'invoices'
      params = { icn: @current_user.icn }

      response = config.connection.get(endpoint, params)
      response.body
    rescue StandardError => e
      handle_error(e, nil, endpoint)
    end

    def handle_error(error, lighthouse_client_id = nil, endpoint = nil, options = {})
      Rails.logger.error("LightHouse Invoice Service - #{error.message}")

      Lighthouse::ServiceException.send_error(
        error,
        self.class.to_s.underscore,
        lighthouse_client_id,
        "#{config.invoice_url}/#{endpoint}",
        options
      )

      raise error
    end
  end
end
