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
  attribute :dslogon_edipi # this is only available for dslogon users
  attribute :sign_in, Hash # original sign_in (see sso_service#mergable_identity_attributes)

  validates :uuid, presence: true
  validates :loa, presence: true
  validate  :loa_highest_present

  private

  def loa_highest_present
    errors.add(:loa, 'loa[:highest] is not present!') if loa[:highest].blank?
  end
end
