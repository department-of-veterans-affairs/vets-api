# frozen_string_literal: true
module EMISRedis
  class Payment < Model
    CLASS_NAME = 'PaymentService'

    def receives_va_pension
      items_from_response('get_retirement_pay').each do |retirement_pay|
        return true if retirement_pay.monthly_gross_amount.positive?
      end

      false
    end
  end
end
