# frozen_string_literal: true

module Debts
  class Service < Common::Client::Base
    configuration Debts::Configuration

    def get_debt_details(body)
      GetLettersResponse.new(perform(:post, 'debtdetails/get', body).body)
    end

    def get_debt_history(body)
      GetLettersResponse.new(perform(:post, 'letterhistory/get', body).body)
    end
  end
end
