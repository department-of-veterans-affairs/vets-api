# frozen_string_literal: true

# It's important that the datetime columns on this table fit a "#{name}_at" pattern
# where the name matches one of the service_names in the SAML::User::AUTHN_CONTEXTS hash.
class AccountLoginStat < ApplicationRecord
  VERIFICATION_LEVELS = %w[loa1 loa3 ial1 ial2].freeze

  belongs_to :account, inverse_of: :login_stats
  validates :account_id, uniqueness: true
  validates :current_verification, inclusion: { in: VERIFICATION_LEVELS, allow_nil: true }
end
