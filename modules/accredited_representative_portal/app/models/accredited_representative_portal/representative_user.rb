# frozen_string_literal: true

module AccreditedRepresentativePortal
  class RepresentativeUser < Common::RedisStore
    redis_store REDIS_CONFIG[:representative_user_store][:namespace]
    redis_ttl REDIS_CONFIG[:representative_user_store][:each_ttl]
    redis_key :uuid

    # in alphabetical order
    attribute :authn_context, String
    attribute :email, String
    attribute :fingerprint, String
    attribute :first_name, String
    attribute :icn, String
    attribute :idme_uuid, String
    attribute :last_name, String
    attribute :last_signed_in, Common::UTCTime
    attribute :loa, String
    attribute :logingov_uuid, String
    attribute :sign_in, Hash
    attribute :user_account_uuid, String
    attribute :uuid, String

    alias_attribute :mhv_icn, :icn

    validates(
      :uuid, :user_account_uuid, :email,
      :first_name, :last_name, :icn,
      presence: true
    )

    def user_account
      @user_account ||= UserAccount.find_by(id: user_account_uuid)
    end

    def power_of_attorney_holders
      @power_of_attorney_holders ||=
        PowerOfAttorneyHolder
        .for_user(email:, icn:)
        .freeze
    end

    def flipper_id
      email&.downcase
    end
  end
end
