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
    attribute :all_emails, Array
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
      @user_account ||=
        RepresentativeUserAccount.find(user_account_uuid).tap do |account|
          account.set_all_emails(all_emails)
        end
    end

    def power_of_attorney_holder_memberships
      @power_of_attorney_holder_memberships ||=
        PowerOfAttorneyHolderMemberships.new(
          icn:, emails: all_emails
        )
    end

    def flipper_id
      email&.downcase
    end
  end
end
