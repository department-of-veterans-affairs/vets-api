# frozen_string_literal: true

module AccreditedRepresentativePortal
  class RepresentativeUser < Common::RedisStore
    redis_store REDIS_CONFIG[:representative_user_store][:namespace]
    redis_ttl REDIS_CONFIG[:representative_user_store][:each_ttl]
    redis_key :uuid

    attribute :uuid
    attribute :email
    attribute :first_name
    attribute :last_name
    attribute :icn
    alias_attribute :mhv_icn, :icn
    attribute :idme_uuid
    attribute :logingov_uuid
    attribute :fingerprint
    attribute :last_signed_in
    attribute :authn_context
    attribute :loa
    attribute :sign_in

    validates :uuid, :email, :first_name, :last_name, :icn, presence: true
  end
end
