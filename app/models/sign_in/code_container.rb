# frozen_string_literal: true

module SignIn
  class CodeContainer < Common::RedisStore
    redis_store REDIS_CONFIG[:sign_in_code_container][:namespace]
    redis_ttl REDIS_CONFIG[:sign_in_code_container][:each_ttl]
    redis_key :code

    attribute :code_challenge, String
    attribute :code, String
    attribute :user_account_uuid, String

    validates(:code_challenge, :code, :user_account_uuid, presence: true)
  end
end
