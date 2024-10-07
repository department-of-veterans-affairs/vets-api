# frozen_string_literal: true

module TravelPay
  class ExpensesService
    def add_expense(veis_token, btsss_token, params = {})
      # check for required params (that don't have a default set in the client)
      unless params['claim_id'] && params['appt_date']
        raise ArgumentError,
              message: 'You must provide a claim ID and appointment date to add an expense.'
      end

      new_expense_response = client.add_mileage_expense(veis_token, btsss_token, params)

      new_expense_response.body
    end

    private

    def client
      TravelPay::ExpensesClient.new
    end
  end
end
