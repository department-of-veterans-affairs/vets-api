# frozen_string_literal: true

require 'common/models/base'
require 'common/models/redis_store'
require 'saml/user'

# Stores attributes used to identify a user. Serves as a set of inputs to an MVI lookup. Also serves
# as the receiver of identity attributes received from alternative sources during the SSO flow.
class UserIdentity < Common::RedisStore
  redis_store REDIS_CONFIG[:user_identity_store][:namespace]
  redis_ttl REDIS_CONFIG[:user_identity_store][:each_ttl]
  redis_key :uuid

  # identity attributes
  attribute :uuid
  attribute :email
  attribute :first_name
  attribute :middle_name
  attribute :last_name
  attribute :common_name
  attribute :gender
  attribute :birth_date
  attribute :birls_id
  attribute :participant_id
  attribute :icn
  attribute :zip
  attribute :ssn
  attribute :loa
  attribute :multifactor, Boolean # used by F/E to decision on whether or not to prompt user to add MFA
  attribute :authn_context # used by F/E to handle various identity related complexities pending refactor
  attribute :idme_uuid
  attribute :sec_id
  attribute :mhv_icn # only needed by B/E not serialized in user_serializer
  attribute :mhv_correlation_id # this is the cannonical version of MHV Correlation ID, provided by MHV sign-in users
  attribute :mhv_account_type # this is only available for MHV sign-in users
  attribute :edipi # this is only available for dslogon users
  attribute :sign_in, Hash # original sign_in (see sso_service#mergable_identity_attributes)
  attribute :icn_with_aaid
  attribute :search_token

  validates :uuid, presence: true
  validates :loa, presence: true
  validate  :loa_highest_present

  # LOA3 no longer just means ID.me FICAM LOA3.
  # It could also be DSLogon or MHV Premium users.
  # It could also be DSLogon or MHV NON PREMIUM users who have done ID.me FICAM LOA3.
  # Additionally, LOA3 does not automatically mean user has opted to have MFA.
  # See also lib/saml/user_attributes/dslogon.rb
  # See also lib/saml/user_attributes/mhv
  def loa3?
    loa[:current].try(:to_i) == LOA::THREE
  end

  with_options if: :loa3? do
    validates :ssn, format: /\A\d{9}\z/, allow_blank: true
    validates :gender, format: /\A(M|F)\z/, allow_blank: true
  end

  private

  def loa_highest_present
    errors.add(:loa, 'loa[:highest] is not present!') if loa[:highest].blank?
  end
end
