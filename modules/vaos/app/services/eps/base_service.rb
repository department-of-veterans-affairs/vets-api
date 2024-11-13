# frozen_string_literal: true

module EPS
  class BaseService < VAOS::SessionService
    private

    def perform(method, path, params, headers = nil, options = nil)
      response = super(method, path, params, headers, options)
      user_service.extend_session(@user.account_uuid) unless Flipper.enabled?(STS_OAUTH_TOKEN, @user)
      response
    end

    def headers
      {
        'Authorization' => "Bearer #{EPS::TokenService.token}",
        'Content-Type' => 'application/json',
        'X-Request-ID' => RequestStore.store['request_id']
      }
    end

    def config
      EPS::Configuration.instance
    end
  end
end