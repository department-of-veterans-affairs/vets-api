# frozen_string_literal: true
require 'common/client/configuration/soap'

module EMIS
  class PaymentConfiguration < Configuration
    URL = Settings.emis.payment_url

    def base_path
      Settings.emis.payment_url
    end

    def service_name
      'EmisPayment'
    end
  end
end
