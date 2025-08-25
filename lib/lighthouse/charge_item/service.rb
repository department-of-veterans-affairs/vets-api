# frozen_string_literal: true

require 'lighthouse/charge_item/configuration'
require 'lighthouse/service_exception'
require 'common/exceptions/bad_request'

module ChargeItem
  class Service < Common::Client::Base
    configuration Lighthouse::ChargeItem::Configuration
    STATSD_KEY_PREFIX = 'api.lighthouse.charge_item'

    def initialize(invoice_id)
      @invoice_id = invoice_id
      super()
    end

    def get_charge_items
      endpoint = "#{config.charge_item_url}/#{@invoice_id}"
      response = config.connection.get(endpoint)
      response.body
    rescue StandardError => e
      handle_error(e, nil, endpoint)
    end

    def handle_error(error, lighthouse_client_id = nil, endpoint = nil, options = {})
      Rails.logger.error("LightHouse Charge Item Service - #{error.message}")

      Lighthouse::ServiceException.send_error(
        error,
        self.class.to_s.underscore,
        lighthouse_client_id,
        "#{config.charge_item_url}/#{endpoint}",
        options
      )

      raise error
    end
  end
end
