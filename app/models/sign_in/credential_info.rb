# frozen_string_literal: true

module SignIn
  class CredentialInfo < Common::RedisStore
    redis_store REDIS_CONFIG[:sign_in_credential_info][:namespace]
    redis_ttl REDIS_CONFIG[:sign_in_credential_info][:each_ttl]
    redis_key :csp_uuid

    attribute :id_token, String
    attribute :csp_uuid, String
    attribute :credential_type, String

    validates(:csp_uuid, :id_token, presence: true)
    validates(:credential_type, inclusion: { in: Constants::Auth::REDIRECT_URLS })
  end
end
