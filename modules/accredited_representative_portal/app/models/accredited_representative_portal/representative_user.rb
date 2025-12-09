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

    delegate(
      :power_of_attorney_holders,
      :registration_numbers,
      to: :power_of_attorney_holder_memberships
    )

    delegate :loa3?, to: :user_identity

    def representative?
      power_of_attorney_holder_memberships.present?
    end

    def power_of_attorney_holder_memberships
      @power_of_attorney_holder_memberships ||=
        PowerOfAttorneyHolderMemberships.new(
          icn:, emails: all_emails
        )
    end

    def user_account
      @user_account ||= UserAccount.find(user_account_uuid)
    end

    def flipper_id
      email&.downcase
    end

    private

    def user_identity
      @user_identity ||= UserIdentity.new(
        uuid:,
        loa:
      )
    end
  end
end
