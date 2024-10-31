# frozen_string_literal: true

class UserAccountDelegation < ApplicationRecord
  belongs_to :verified_account, class_name: 'UserAccount', foreign_key: 'verified_user_account_icn',
                                primary_key: 'icn', inverse_of: :account_delegations_as_verified

  belongs_to :delegated_account, class_name: 'UserAccount', foreign_key: 'delegated_user_account_icn',
                                 primary_key: 'icn', inverse_of: :account_delegations_as_delegated

  def self.delegate_access(verified_user_account_icn:, delegated_user_account_icn:)
    raise 'Cannot delegate access to the same account' if verified_user_account_icn == delegated_user_account_icn

    find_or_create_by!(verified_user_account_icn:, delegated_user_account_icn:)
  end
end
