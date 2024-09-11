# frozen_string_literal: true

module TravelPay
  class TokenService
    #
    # returns a hash containing the veis_token & btsss_token
    #
    def get_tokens(current_user)
      veis_token = token_client.request_veis_token
      btsss_token = token_client.request_btsss_token(veis_token, current_user)

      { veis_token:, btsss_token: }
    end

    private

    def token_client
      TravelPay::TokenClient.new
    end
  end
end
