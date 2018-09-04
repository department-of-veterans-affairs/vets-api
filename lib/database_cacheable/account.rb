# frozen_string_literal: true

module DatabaseCacheable
  # The purpose of this module is to wrap around an Account record
  # for caching, as well as providing a #cache? method to meet CacheAside
  # implementation criteria
  #
  # @see lib/common/models/concerns/cache_aside.rb
  #
  class Account
    attr_reader :user_account

    def initialize(user)
      @user_account = fetch_attributes_for(user)
    end

    def cache?
      user_account.presence
    end

    private

    def fetch_attributes_for(user)
      account = ::Account.create_if_needed! user

      account&.attributes
    end
  end
end
