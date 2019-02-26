# frozen_string_literal: true

# Subclasses the `User` model in order to override the redis namespace and thereby partition user
# sessions for va.gov from openid client applications.
class OpenidUser < ::User
  redis_store REDIS_CONFIG['openid_user_store']['namespace']
  redis_ttl REDIS_CONFIG['openid_user_store']['each_ttl']
  redis_key :uuid

  def identity
    @identity ||= OpenidUserIdentity.find(uuid)
  end

  def self.build_from_identity(identity:, ttl:)
    user = new(identity.attributes)
    user.expire(ttl)
    user
  end
end
