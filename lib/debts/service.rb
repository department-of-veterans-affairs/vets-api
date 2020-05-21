# frozen_string_literal: true

module Debts
  class Service < Common::Client::Base
    configuration Debts::Configuration

    def get_letters(body)
      GetLettersResponse.new(request(:post, 'letterdetails/get', body).body)
    end
  end
end
