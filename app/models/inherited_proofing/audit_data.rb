# frozen_string_literal: true

module InheritedProofing
  class AuditData < Common::RedisStore
    redis_store REDIS_CONFIG[:inherited_proofing_audit][:namespace]
    redis_ttl REDIS_CONFIG[:inherited_proofing_audit][:each_ttl]
    redis_key :code

    attribute :user_uuid, String
    attribute :code, String
    attribute :legacy_csp, String

    validates(:user_uuid, :code, :legacy_csp, presence: true)
  end
end
