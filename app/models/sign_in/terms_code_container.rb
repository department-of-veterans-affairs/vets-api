# frozen_string_literal: true

module SignIn
  class TermsCodeContainer < Common::RedisStore
    redis_store REDIS_CONFIG[:sign_in_terms_code_container][:namespace]
    redis_ttl REDIS_CONFIG[:sign_in_terms_code_container][:each_ttl]
    redis_key :code

    attribute :code, String
    attribute :user_account_uuid, String

    validates(:code, :user_account_uuid, presence: true)
  end
end
