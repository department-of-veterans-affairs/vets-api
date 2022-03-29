# frozen_string_literal: true

module InheritedProofing
  class MHVIdentityData < Common::RedisStore
    redis_store REDIS_CONFIG[:mhv_identity_data][:namespace]
    redis_ttl REDIS_CONFIG[:mhv_identity_data][:each_ttl]
    redis_key :code

    attribute :user_uuid, String
    attribute :code, String
    attribute :data, Hash

    validates(:user_uuid, :code, :data, presence: true)
  end
end
