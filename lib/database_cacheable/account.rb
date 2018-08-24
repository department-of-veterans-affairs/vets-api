module DatabaseCacheable
  class Account
    attr_reader :user_account

    def initialize(user)
      @user_account = user.account&.attributes
    end

    def cache?
      user_account.presence
    end
  end
end
