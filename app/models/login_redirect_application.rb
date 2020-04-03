# frozen_string_literal: true

require 'common/models/redis_store'

# Users logging in via SSOe may need to be redirected back to an external
# application after authentication rather than the VA.gov home page.  When a
# authentication request comes in, with the necessary parameter, we can use
# this Redis namespace to temporarily store a value so that when a matching
# SAML response comes back from SSOe we know where to redirect the newly
# authenticated user.
class LoginRedirectApplication < Common::RedisStore
  redis_store REDIS_CONFIG['login_redirect_application']['namespace']
  redis_ttl REDIS_CONFIG['login_redirect_application']['each_ttl']
  redis_key :uuid

  attribute :uuid
  attribute :redirect_application

  validates :uuid, presence: true
  validates :redirect_application, presence: true
end
