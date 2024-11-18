# frozen_string_literal: true

module Eps
  class BaseService < Common::Client::Base
    STS_OAUTH_TOKEN = :va_online_scheduling_sts_oauth_token

    attr_accessor :user

    def initialize(user)
      super() if defined?(super)
      @user = user
    end

    def perform(method, path, params, headers = nil, options = nil)
      response = super(method, path, params, headers, options)
      user_service.extend_session(@user.account_uuid) unless Flipper.enabled?(STS_OAUTH_TOKEN, @user)
      response
    end

    private

    def user_service
      @user_service ||= VAOS::UserService.new
    end

    def headers
      {
        'Authorization' => 'Bearer 1234',
        'Content-Type' => 'application/json',
        'X-Request-ID' => RequestStore.store['request_id']
      }
    end

    def config
      Eps::Configuration.instance
    end
  end
end
