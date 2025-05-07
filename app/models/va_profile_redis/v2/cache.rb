# frozen_string_literal: true

require 'sentry_logging'

module VAProfileRedis
  module V2
    class Cache
      include SentryLogging

      # Invalidates the cache set in VAProfileRedis::V2::ContactInformation through
      # our Common::RedisStore#destroy method.
      #
      # @param user [User] The current user
      #
      def self.invalidate(user)
        return if user&.icn.blank?

        contact_info = VAProfileRedis::V2::ContactInformation.find(user.icn)
        contact_info.destroy if contact_info.present?
      end
    end
  end
end
