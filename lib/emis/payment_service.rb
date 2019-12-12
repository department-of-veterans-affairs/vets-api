# frozen_string_literal: true

require 'emis/service'
require 'emis/payment_configuration'

module EMIS
  # HTTP Client for EMIS Payment Service requests.
  class PaymentService < Service
    configuration EMIS::PaymentConfiguration

    create_endpoints(
      %i[
        get_combat_pay
        get_reserve_drill_days
        get_retirement_pay
        get_separation_pay
      ]
    )

    protected

    # Custom namespaces used in EMIS SOAP request message
    # @return [Config::Options] Custom namespaces object
    def custom_namespaces
      Settings.emis.payment.v1.soap_namespaces
    end
  end
end
