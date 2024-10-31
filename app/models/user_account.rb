# frozen_string_literal: true

class UserAccount < ApplicationRecord
  has_many :form_submissions, dependent: :nullify
  has_many :user_verifications, dependent: :destroy
  has_many :terms_of_use_agreements, dependent: :destroy
  has_one :user_acceptable_verified_credential, dependent: :destroy
  has_one :veteran_onboarding, primary_key: :uuid, foreign_key: :user_account_uuid, inverse_of: :user_account,
                               dependent: :destroy
  # Delegations where this account is the verified account
  has_many :account_delegations_as_verified, class_name: 'UserAccountDelegation',
                                             foreign_key: 'verified_user_account_icn', primary_key: 'icn',
                                             dependent: :destroy, inverse_of: :verified_account
  has_many :delegated_accounts, through: :account_delegations_as_verified, source: :delegated_account

  # Delegations where this account is the delegated account
  has_many :account_delegations_as_delegated, class_name: 'UserAccountDelegation',
                                              foreign_key: 'delegated_user_account_icn', primary_key: 'icn',
                                              dependent: :destroy, inverse_of: :delegated_account
  has_many :verified_accounts, through: :account_delegations_as_delegated, source: :verified_account

  validates :icn, uniqueness: true, allow_nil: true

  def verified?
    icn.present?
  end

  def needs_accepted_terms_of_use?
    verified? && !accepted_current_terms_of_use?
  end

  private

  def accepted_current_terms_of_use?
    terms_of_use_agreements.current.last&.accepted?
  end
end
