# frozen_string_literal: true

module MockedAuthentication
  class CredentialInfo < Common::RedisStore
    redis_store REDIS_CONFIG[:mock_credential_info][:namespace]
    redis_ttl REDIS_CONFIG[:mock_credential_info][:each_ttl]
    redis_key :credential_info_code

    attribute :credential_info_code, String
    attribute :credential_info

    validates(:credential_info_code, presence: true)
  end
end
