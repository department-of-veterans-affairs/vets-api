# frozen_string_literal: true

require 'common/client/configuration/soap'

module EMIS
  class PaymentConfiguration < Configuration
    def base_path
      URI.join(Settings.emis.host, Settings.emis.payment_url).to_s
    end

    # :nocov:
    def service_name
      'EmisPayment'
    end
    # :nocov:
  end
end
