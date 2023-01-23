# frozen_string_literal: true

module Identity
  class AccountCreator
    def initialize(user)
      @user = user
    end

    attr_accessor :user

    def call
      return unless user.idme_uuid || user.logingov_uuid

      account = create_if_needed!

      update_if_needed!(account)
    end

    private

    def create_if_needed!
      accounts = get_accounts_for_user
      account = accounts.length > 1 ? find_matching_account(accounts) : accounts.first
      account.presence || Account.create(**create_account_attribute_hash(user))
    end

    def get_accounts_for_user
      Account.idme_uuid_match(user.idme_uuid)
             .or(Account.sec_id_match(user.sec_id))
             .or(Account.logingov_uuid_match(user.logingov_uuid))
    end

    def find_matching_account(accounts)
      match_account_for_identifier(accounts, :idme_uuid) ||
        match_account_for_identifier(accounts, :logingov_uuid) ||
        accounts.first
    end

    def match_account_for_identifier(accounts, identifier)
      user_identifier_id = user.send(identifier)
      return unless user_identifier_id

      accounts.find { |account| account.send(identifier) == user_identifier_id }
    end

    def create_account_attribute_hash(identity)
      {
        idme_uuid: identity.idme_uuid,
        logingov_uuid: identity.logingov_uuid,
        sec_id: identity.sec_id,
        edipi: identity.edipi,
        icn: identity.icn
      }.compact
    end

    def update_if_needed!(account)
      # account has yet to be saved, no need to update
      return account unless account.persisted?

      # return account as is if all non-nil user attributes match up to be the same
      account_attributes = create_account_attribute_hash(account)
      user_attributes = create_account_attribute_hash(user)
      attribute_diff = hash_diff(user_attributes, account_attributes)

      return account if attribute_diff.blank?

      if attribute_diff[:logingov_uuid]
        clean_up_deprecated_accounts(account.id,
                                     attribute_diff[:logingov_uuid],
                                     :logingov_uuid)
      end

      Account.update(account.id, **user_attributes)
    end

    def hash_diff(first_hash, second_hash)
      (first_hash.to_a - second_hash.to_a).to_h
    end

    def clean_up_deprecated_accounts(current_account_id, uuid, identifier)
      return unless uuid

      account = Account.find_by(identifier => uuid)

      account.destroy if account && account.id != current_account_id
    end
  end
end
