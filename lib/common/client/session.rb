# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/attribute_types/utc_time'
module Common
  module Client
    # A generic session model - see how RX implements it
    class Session < Common::RedisStore
      EXPIRATION_THRESHOLD_SECONDS = 20

      attribute :user_id, Integer
      attribute :expires_at, Common::UTCTime
      attribute :token, String
      attribute :user_uuid, String

      validates_numericality_of :user_id

      def self.find_or_build(attributes)
        find(attributes[redis_namespace_key]) || new(attributes)
      end

      def expired?
        return true if expires_at.nil?

        expires_at.to_i <= Time.now.utc.to_i + EXPIRATION_THRESHOLD_SECONDS
      end

      def original_json
        nil
      end
    end
  end
end
