# frozen_string_literal: true

require 'common/models/redis_store'

module MAP
  module SecurityToken
    class MapStsToken < Common::RedisStore
      redis_store REDIS_CONFIG[:map_sts_token][:namespace]
      redis_ttl REDIS_CONFIG[:map_sts_token][:each_ttl]
      redis_key :icn

      attribute :icn, String
      attribute :application, String
      attribute :access_token, String
      attribute :expiration, String

      validates :icn, presence: true
    end
  end
end
