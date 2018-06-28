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

      instance = new
      instance.log("Vet360: Response cache exists before invalidation: #{redis_key_exists(user)}")

      if contact_info.present?
        contact_info.destroy
        instance.log("Vet360: Response cache exists after invalidation: #{redis_key_exists(user)}")
      else
        instance.log('Vet360: Cannot invalidate a nil response cache')
      end
    end

    def self.redis_key_exists(user)
      Redis.current.exists("vet360-contact-info-response:#{user.uuid}")
    end

    def log(message)
      log_message_to_sentry(message, :info)
    end
  end
end
