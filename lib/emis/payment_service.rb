# frozen_string_literal: true
require 'emis/service'
require 'emis/payment_configuration'
require 'emis/errors/errors'

module EMIS
  class PaymentService < Service
    configuration EMIS::PaymentConfiguration

    def get_veteran_status(edipi: nil, icn: nil)
      make_request(
        edipi: edipi,
        icn: icn,
        operation: 'getVeteranStatus',
        response_type: EMIS::Responses::GetVeteranStatusResponse
      )
    end
  end
end
