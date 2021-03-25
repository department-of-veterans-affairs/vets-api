# frozen_string_literal: true

module Swagger
  module Schemas
    class PaymentHistory
      include Swagger::Blocks

      swagger_schema :PaymentHistory do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            property :payments, type: :array, example: [
              {
                pay_check_dt: '2017-12-29T00:00:00.000-06:00',
                pay_check_amount: '$3,261.10',
                pay_check_type: 'Compensation & Pension - Recurring',
                payment_method: 'Direct Deposit',
                bank_name: 'NAVY FEDERAL CREDIT UNION',
                account_number: '***4567'
              }
            ]
            property :return_payments, type: :array, example: [
              {
                returned_check_issue_dt: '2012-12-15T00:00:00.000-06:00',
                returned_check_cancel_dt: '2013-01-01T00:00:00.000-06:00',
                returned_check_amount: '$50.00',
                returned_check_number: '12345678',
                returned_check_type: 'CH31 VR&E',
                return_reason: 'Other Reason'
              }
            ]
          end
        end
      end
    end
  end
end
