# frozen_string_literal: true

module EMIS
  # HTTP Client for EMIS Payment Service requests.
  class PaymentServiceV2 < Service
    configuration EMIS::PaymentConfigurationV2

    create_endpoints(
      %i[
        get_pay_grade_history
      ]
    )

    protected

    # Custom namespaces used in EMIS SOAP request message
    # @return [Config::Options] Custom namespaces object
    def custom_namespaces
      Settings.emis.payment.v2.soap_namespaces
    end
  end
end
