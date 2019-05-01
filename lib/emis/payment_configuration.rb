# frozen_string_literal: true

require 'common/client/configuration/soap'

module EMIS
  # Configuration for {EMIS::PaymentService}
  # includes API URL and breakers service name.
  class PaymentConfiguration < Configuration
    # Payment Service URL
    # @return [String] Payment Service URL
    def base_path
      URI.join(Settings.emis.host, Settings.emis.payment_url).to_s
    end

    # :nocov:

    # Payment Service breakers name
    # @return [String] Payment Service breakers name
    def service_name
      'EmisPayment'
    end
    # :nocov:
  end
end
