# frozen_string_literal: true

require 'common/models/base'
require 'common/models/redis_store'
require 'saml/user'

class UserIdentity < Common::RedisStore
  redis_store REDIS_CONFIG['user_identity_store']['namespace']
  redis_ttl REDIS_CONFIG['user_identity_store']['each_ttl']
  redis_key :uuid

  # identity attributes
  attribute :uuid
  attribute :email
  attribute :first_name
  attribute :middle_name
  attribute :last_name
  attribute :gender
  attribute :birth_date
  attribute :zip
  attribute :ssn
  attribute :loa
  attribute :multifactor, Boolean # used by F/E to decision on whether or not to prompt user to add MFA
  attribute :authn_context # used by F/E to handle various identity related complexities pending refactor
  attribute :mhv_icn # only needed by B/E not serialized in user_serializer
  attribute :mhv_correlation_id # this is the cannonical version of MHV Correlation ID, provided by MHV sign-in users
  attribute :mhv_account_level # this is only available for MHV sign-in users

  validates :uuid, presence: true
  validates :email, presence: true
  validates :loa, presence: true
end
