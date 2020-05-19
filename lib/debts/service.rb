module Debts
  class Service < Common::Client::Base
    configuration Debts::Configuration

    def get_letters(body)
      request(:post, 'letterdetails/get', body)
    end
  end
end
