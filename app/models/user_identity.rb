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
  attribute :multifactor   # used by F/E to decision on whether or not to prompt user to add MFA
  attribute :authn_context # used by F/E to handle various identity related complexities pending refactor
  attribute :mhv_icn # only needed by B/E not serialized in user_serializer
  attribute :mhv_uuid # this is the cannonical version of MHV Correlation ID, provided by MHV sign-in users
  validates :uuid, presence: true
  validates :email, presence: true
  validates :loa, presence: true


  def self.from_merged_attrs(existing_user, new_user)
    # we want to always use the more recent attrs so long as they exist
    attrs = new_user.attributes.map do |key, val|
      { key => val.presence || existing_user[key] }
    end.reduce({}, :merge)

    # for loa, we want the higher of the two
    attrs[:loa][:current] = [existing_user[:loa][:current], new_user[:loa][:current]].max
    attrs[:loa][:highest] = [existing_user[:loa][:highest], new_user[:loa][:highest]].max

    User.new(attrs)
  end
end
