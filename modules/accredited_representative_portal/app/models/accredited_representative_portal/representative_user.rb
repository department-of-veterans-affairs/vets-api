# frozen_string_literal: true

module AccreditedRepresentativePortal
  class RepresentativeUser < Common::RedisStore
    redis_store REDIS_CONFIG[:representative_user_store][:namespace]
    redis_ttl REDIS_CONFIG[:representative_user_store][:each_ttl]
    redis_key :uuid

    # in alphabetical order
    attribute :authn_context
    attribute :email
    attribute :fingerprint
    attribute :first_name
    attribute :icn
    attribute :idme_uuid
    attribute :last_name
    attribute :last_signed_in
    attribute :loa
    attribute :logingov_uuid
    attribute :ogc_registration_number
    attribute :poa_codes
    attribute :sign_in
    attribute :uuid
    alias_attribute :mhv_icn, :icn

    validates :uuid, :email, :first_name, :last_name, :icn, presence: true

    def flipper_id
      email&.downcase
    end

    # TODO: What's this for?
    def user_account
      nil
    end
  end
end
