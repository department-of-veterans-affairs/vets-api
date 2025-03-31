# frozen_string_literal: true

module VAOS
  class SessionService < VAOS::BaseService
    attr_accessor :user

    def initialize(user)
      @user = user
    end

    private

    def perform(method, path, params, headers = nil, options = nil)
      super(method, path, params, headers, options)
    end

    def headers
      {
        'Referer' => referrer,
        'X-VAMF-JWT' => user_service.session(@user),
        'X-Request-ID' => RequestStore.store['request_id']
      }
    end

    def user_service
      @user_service ||= VAOS::UserService.new
    end
  end
end
