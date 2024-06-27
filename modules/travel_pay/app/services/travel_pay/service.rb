# frozen_string_literal: true

module TravelPay
  class Service
    def ping
      veis_token = client.request_veis_token
      client.ping(veis_token)
    end

    def authorized_ping(current_user)
      sts_token = client.request_sts_token(current_user)
      veis_token = client.request_veis_token
      btsss_token = client.request_btsss_token(veis_token, sts_token)

      client.authorized_ping(veis_token, btsss_token)
    end

    def get_claims(current_user)
      veis_token = client.request_veis_token

      sts_token = client.request_sts_token(current_user)
      btsss_token = client.request_btsss_token(veis_token, sts_token)

      client.get_claims(veis_token, btsss_token)
    end

    private

    def client
      TravelPay::Client.new
    end
  end
end
