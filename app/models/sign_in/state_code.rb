# frozen_string_literal: true

module SignIn
  class StateCode < Common::RedisStore
    redis_store REDIS_CONFIG[:sign_in_state_code][:namespace]
    redis_ttl REDIS_CONFIG[:sign_in_state_code][:each_ttl]
    redis_key :code

    attribute :code, String

    validates(:code, presence: true)
  end
end
