# frozen_string_literal: true

module HealthQuest
  class SessionService < HealthQuest::BaseService
    attr_accessor :user

    def initialize(user)
      @user = user
    end

    private

    def perform(method, path, params, headers = nil, options = nil)
      response = super(method, path, params, headers, options)
      user_service.extend_session(@user.account_uuid)
      response
    end

    def headers
      {
        'Referer' => referrer,
        'X-VAMF-JWT' => user_service.session(@user),
        'X-Request-ID' => RequestStore.store['request_id']
      }
    end

    def user_service
      @user_service ||= HealthQuest::UserService.new
    end
  end
end
