# frozen_string_literal: true

module Auth
  module ClientCredentials
    class AccessTokenTracker < Common::RedisStore
      redis_store REDIS_CONFIG[:lighthouse_ccg][:namespace]
      redis_ttl REDIS_CONFIG[:lighthouse_ccg][:each_ttl]
      redis_key :service_name

      TOLERANCE = 5

      attribute :service_name, String
      attribute :access_token, String

      validates(:access_token, presence: true)

      def self.set_access_token(service_name, access_token, ttl = redis_namespace_ttl)
        service = new(service_name:)
        service.access_token = access_token
        service.save!

        # We want to set the TTL dynamically
        # Using TOLERANCE here so that we can avoid using the access_token right as
        # it is expiring
        service.expire(ttl - TOLERANCE)
      end

      def self.get_access_token(service_name)
        service = find(service_name)
        service&.access_token
      end
    end
  end
end
