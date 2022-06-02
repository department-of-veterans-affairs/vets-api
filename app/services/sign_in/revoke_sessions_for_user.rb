# frozen_string_literal: true

module SignIn
  class RevokeSessionsForUser
    attr_reader :user_uuid, :sessions

    def initialize(user_uuid:)
      @user_uuid = user_uuid
    end

    def perform
      delete_sessions!
    end

    private

    def user_account
      @user_account ||= UserAccount.find(user_uuid)
    end

    def delete_sessions!
      SignIn::OAuthSession.where(user_account: user_account).destroy_all
    end
  end
end
