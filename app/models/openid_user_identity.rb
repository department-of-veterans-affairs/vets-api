# frozen_string_literal: true

require 'okta/user_profile'

# Subclasses the UserIdentity class in order to override the redis namespace and thereby partition
# user sessions for va.gov from openid client applications.
class OpenidUserIdentity < ::UserIdentity
  redis_store REDIS_CONFIG[:openid_user_identity_store][:namespace]
  redis_ttl REDIS_CONFIG[:openid_user_identity_store][:each_ttl]
  redis_key :uuid

  # @param uuid [String] the UUID of the user, as they are known to the upstream identity provider.
  # @param profile [Okta::UserProfile] the profile of the user, as they are known to okta.
  # @param ttl [Integer] the time to store the identity in redis.
  # @return [OpenidUserIdentity]
  def self.build_from_profile(uuid:, profile:, ttl:)
    identity = new(
      uuid:,
      email: profile['email'],
      first_name: profile['firstName'],
      middle_name: profile['middleName'],
      last_name: profile['lastName'],
      mhv_icn: profile['icn'],
      icn: profile['icn'],
      loa: profile.derived_loa
    )
    identity.expire(ttl)
    identity
  end
end
