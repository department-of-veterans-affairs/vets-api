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

    validates(:code_challenge, :code, :user_verification_id, presence: true)

    validate :confirm_client_id

    private

    def confirm_client_id
      errors.add(:base, 'Client id must map to a configuration') unless ClientConfig.valid_client_id?(client_id:)
    end
  end
end
