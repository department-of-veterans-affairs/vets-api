# frozen_string_literal: true

module SignIn
  class CodeChallengeStateMap < Common::RedisStore
    redis_store REDIS_CONFIG[:code_challenge_state_map][:namespace]
    redis_ttl REDIS_CONFIG[:code_challenge_state_map][:each_ttl]
    redis_key :state

    attribute :code_challenge, String
    attribute :state, String

    validates(:code_challenge, :state, presence: true)
  end
end
