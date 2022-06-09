# frozen_string_literal: true

module SignIn
  class CodeContainer < Common::RedisStore
    redis_store REDIS_CONFIG[:sign_in_code_container][:namespace]
    redis_ttl REDIS_CONFIG[:sign_in_code_container][:each_ttl]
    redis_key :code

    attribute :code_challenge, String
    attribute :code, String
    attribute :client_id, String
    attribute :user_verification_id, Integer
    attribute :credential_email, String

    validates(:client_id, inclusion: { in: Constants::Auth::CLIENT_IDS })
    validates(:code_challenge, :code, :user_verification_id, presence: true)
  end
end
