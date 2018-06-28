# frozen_string_literal: true

require 'sentry_logging'

module Vet360Redis
  class Cache
    include SentryLogging

    # Invalidates the cache set in Vet360Redis::ContactInformation through
    # our Common::RedisStore#destroy method.
    #
    # @param user [User] The current user
    #
    def self.invalidate(user)
      contact_info = user.vet360_contact_info

      # TODO: This is a hack to check whether the uuid for the user will be populated from redis
      contact_info.email
      
      instance = new

      if contact_info.present?
        uuid = contact_info.attributes[:uuid]
        count = contact_info.destroy

        # TODO: Remove once caching bug has been fixed
        instance.log("Vet360: Cache invalidation destroyed #{count} keys '#{uuid}'")
      else
        instance.log('Vet360: Cannot invalidate a nil response cache')
      end
    end

    def log(message)
      log_message_to_sentry(message, :info)
    end
  end
end
