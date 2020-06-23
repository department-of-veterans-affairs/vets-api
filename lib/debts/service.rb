# frozen_string_literal: true

require 'common/client/base'

module Debts
  class Service < Common::Client::Base
    configuration Debts::Configuration

    def get_letters(body)
      GetLettersResponse.new(perform(:post, 'letterdetails/get', body).body)
    end
  end
end
