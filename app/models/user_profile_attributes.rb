# frozen_string_literal: true

require 'common/models/base'
require 'common/models/redis_store'

# Stores attributes used to identify a user. Serves as a set of inputs to an MVI lookup. Also serves
# as the receiver of identity attributes received from alternative sources during the SSO flow.
class UserProfileAttributes < Common::RedisStore
  redis_store REDIS_CONFIG[:user_profile_attributes][:namespace]
  redis_ttl REDIS_CONFIG[:user_profile_attributes][:each_ttl]
  redis_key :uuid

  # identity attributes
  attribute :uuid
  attribute :icn
  attribute :email
  attribute :first_name
  attribute :last_name
  attribute :ssn
  attribute :flipper_id
  validates :uuid, presence: true
end
