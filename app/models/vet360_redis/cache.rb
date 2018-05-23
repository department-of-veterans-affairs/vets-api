# frozen_string_literal: true

module Vet360Redis
  class Cache

    # Invalidates the cache set in Vet360Redis::ContactInformation through
    # our Common::RedisStore#destroy method.
    #
    # @param url [User] The current user
    #
    def self.invalidate(user)
      user.vet360_contact_info&.destroy
    end
  end
end
