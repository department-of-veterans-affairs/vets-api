# frozen_string_literal: true

module TravelPay
  class TokenService
    #
    # GET TOKENS
    # returns a hash containing the veis_token & btsss_token
    ##
    #
    def get_tokens(current_user)
      veis_token = token_client.request_veis_token
      btsss_token = token_client.request_btsss_token(veis_token, current_user)

      { 'veis_token' => veis_token,
        'btsss_token' => btsss_token }
    end

    private

    ##
    # Syntactic sugar for determining if the client should use
    # fake api responses or actually connect to the BTSSS API
    def mock_enabled?
      Settings.travel_pay.mock
    end

    def token_client
      TravelPay::TokenClient.new
    end
  end
end
