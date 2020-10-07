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
                "pay_check_amount": '$3,261.10',
                "pay_check_dt": '04/01/2019',
                "pay_check_id": '001',
                "pay_check_return_fiche": 'C',
                "pay_check_type": 'Compensation & Pension - Recurring'
              }
            ]
            property :return_payments, type: :array, example: [
              {
                "returned_check_amount": '$50.00',
                "returned_check_cancel_dt": '12/01/2012',
                "returned_check_issue_dt": '11/25/2012',
                "returned_check_num": '12345678',
                "returned_check_ro": '17',
                "returned_check_reason": '6',
                "returned_check_return_fiche": 'B',
                "returned_check_type": 'Other'
              }
            ]
          end
        end
      end
    end
  end
end
