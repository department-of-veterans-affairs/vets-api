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
      contact_info = user.vet360_contact_info

      if contact_info.present?
        contact_info.destroy
      else
        new.log_message_to_sentry('VA Profile: Cannot invalidate a nil response cache', :info)
      end
    end
  end
end
