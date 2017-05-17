# frozen_string_literal: true
require 'common/client/configuration/soap'

module EMIS
  class PaymentConfiguration < Configuration
    def base_path
      Settings.emis.payment_url
    end

    # :nocov:
    def service_name
      'EmisPayment'
    end
    # :nocov:
  end
end
