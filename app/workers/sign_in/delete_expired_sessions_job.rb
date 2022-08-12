# frozen_string_literal: true

module SignIn
  class DeleteExpiredSessionsJob
    include Sidekiq::Worker

    def perform
      expired_oauth_sessions.destroy_all
    end

    private

    def time_in_past
      ...Time.zone.now
    end

    def expired_oauth_sessions
      OAuthSession.where(refresh_expiration: time_in_past)
    end
  end
end
