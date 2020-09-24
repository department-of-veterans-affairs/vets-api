# frozen_string_literal: true

module BGS
  class PaymentService < BaseService
    def payment_history
      # rubocop:disable Rails/DynamicFindBy
      response = @service.payment_history.find_by_ssn(@user.ssn)
      # rubocop:enable Rails/DynamicFindBy

      response[:payment_record]
    rescue => e
      return { payment_address: [], payments: [], return_payments: [] } if e.message.include?('No payment record found')

      report_error(e)
    end
  end
end
