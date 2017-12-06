# frozen_string_literal: true

# We're just keeping this around for persistence.
class UserOld < Common::RedisStore
  redis_store REDIS_CONFIG['user_store']['namespace']
  redis_ttl REDIS_CONFIG['user_store']['each_ttl']
  redis_key :uuid

  # id.me attributes
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
  attribute :multifactor, Boolean
  attribute :authn_context
  attribute :mhv_icn
  attribute :mhv_uuid

  attribute :last_signed_in, Common::UTCTime # vaafi attributes
  attribute :mhv_last_signed_in, Common::UTCTime
end
