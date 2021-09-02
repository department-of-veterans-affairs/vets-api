# frozen_string_literal: true

# It's important that the datetime columns on this table fit a "#{name}_at" pattern
# where the name matches one of the service_names in the SAML::User::AUTHN_CONTEXTS hash.
class AccountLoginStat < ApplicationRecord
  # ['idme', 'myhealthevet', 'dslogon']
  LOGIN_TYPES = SAML::User::AUTHN_CONTEXTS.map { |_k, v| v[:sign_in][:service_name] }.uniq.freeze

  belongs_to :account, inverse_of: :login_stats
  validates :account_id, presence: true, uniqueness: true
end
