# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class LighthouseDirectDepositError < ::Lighthouse::DirectDeposit::ErrorParser
        def self.parse_status(status, detail)
          return '500' if detail.include?('accountRoutingNumber.invalidCheckSum') ||
                          detail.include?('payment.accountRoutingNumber.invalid') ||
                          detail.include?('Routing number related to potential fraud')

          status
        end
      end
    end
  end
end
