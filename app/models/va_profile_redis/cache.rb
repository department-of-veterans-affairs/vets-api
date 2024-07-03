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
      contact_info = if Flipper.enabled?(:va_profile_information_v3_redis, user)
                       VAProfileRedis::ProfileInformation.find(user.uuid)
                     else
                       VAProfileRedis::ContactInformation.find(user.uuid)
                     end

      contact_info.destroy if contact_info.present?
    end
  end
end
