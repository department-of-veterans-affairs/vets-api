# frozen_string_literal: true

module VAOS
  class EpsBaseService < VAOS::SessionService
    EPS_AUTH_TOKEN = :EPS_AUTH_TOKEN

    private

    def perform(method, path, params, headers = nil, options = nil)
      response = super(method, path, params, headers, options)
      user_service.extend_session(@user.account_uuid) unless Flipper.enabled?(STS_OAUTH_TOKEN, @user)
      response
    end

    def headers
      {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json',
        'X-Request-ID' => RequestStore.store['request_id']
      }
    end

    def config
      VAOS::EpsConfiguration.instance
    end
  end
end