# frozen_string_literal: true

require 'sentry_logging'

module Identity
  class AccountCreator
    include SentryLogging

    def initialize(user)
      @user = user
    end

    attr_accessor :user

    # Returns the one Account record for the passed in user.
    # @param user [User] An instance of User
    # @return [Account] A persisted instance of Account
    #
    def call
      return unless user.idme_uuid || user.sec_id || user.logingov_uuid

      acct = create_if_needed!(user)

      update_if_needed!(acct, user)
    end

    private

    def create_if_needed!(user)
      accts = Account.idme_uuid_match(user.idme_uuid)
                     .or(Account.sec_id_match(user.sec_id))
                     .or(Account.logingov_uuid_match(user.logingov_uuid))
      accts = sort_with_idme_uuid_priority(accts, user)
      accts.length.positive? ? accts[0] : Account.create(**account_attrs_from_user(user))
    end

    def update_if_needed!(account, user)
      # account has yet to be saved, no need to update
      return account unless account.persisted?

      # return account as is if all non-nil user attributes match up to be the same
      attrs = account_attrs_from_user(user)
      return account if attrs.all? { |k, v| account.try(k) == v }

      diff = { account: account_attrs_from_user(account), user: attrs }
      log_message_to_sentry('Account record does not match User', 'warning', diff)
      Account.update(account.id, **attrs)
    end

    # Build an account attribute hash from the given User attributes
    #
    # @return [Hash]
    #
    def account_attrs_from_user(user)
      {
        idme_uuid: user.idme_uuid,
        logingov_uuid: user.logingov_uuid,
        sec_id: user.sec_id,
        edipi: user.edipi,
        icn: user.icn
      }.compact
    end

    # Sort the given list of Accounts so the ones with matching ID.me UUID values
    # come first in the array, this will provide users with a more consistent
    # experience in the case they have multiple credentials to login with
    # https://github.com/department-of-veterans-affairs/va.gov-team/issues/6702
    #
    # @return [Array]
    #
    def sort_with_idme_uuid_priority(accts, user)
      if accts.length > 1
        data = accts.map { |a| "Account:#{a.id}" }
        log_message_to_sentry('multiple Account records with matching ids', 'warning', data)
        accts = accts.sort_by { |a| a.idme_uuid == user.idme_uuid ? 0 : 1 }
      end
      accts
    end
  end
end
