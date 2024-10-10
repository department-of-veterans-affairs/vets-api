# frozen_string_literal: true

module TravelPay
  class Session
    def initialize(client_number, current_user)
      @client_number = client_number
      @user = current_user
    end

    def get_tokens
      raise NotImplementedError
    end
  end
end
