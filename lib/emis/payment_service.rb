# frozen_string_literal: true

require 'emis/service'
require 'emis/payment_configuration'

module EMIS
  class PaymentService < Service
    configuration EMIS::PaymentConfiguration

    create_endpoints(
      %i(
        get_combat_pay
        get_reserve_drill_days
        get_retirement_pay
        get_separation_pay
      )
    )

    protected

    def custom_namespaces
      Settings.emis.payment.soap_namespaces
    end
  end
end
