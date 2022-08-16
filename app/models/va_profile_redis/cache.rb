# frozen_string_literal: true

require 'sentry_logging'

module VAProfileRedis
  class Cache
    include SentryLogging

    # Invalidates the cache set in VAProfileRedis::ContactInformation through
    # our Common::RedisStore#destroy method.
    #
    # @param user [User] The current user
    #
    def self.invalidate(user)
      contact_info = VAProfileRedis::ContactInformation.find(user.uuid)

      contact_info.destroy if contact_info.present?
    end
  end
end
