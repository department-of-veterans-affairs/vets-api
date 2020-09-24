# frozen_string_literal: true

require 'common/models/redis_store'

# Temporarily store SAML request details, so that on a return SAML response
# we can lookup associated information.
#
# For example, one use case would be for users logging in via SSOe that need
# to be redirected back to an external application after authentication, rather
# than the VA.gov home page. When a authentication request comes in, with the
# necessary parameter, we can use this Redis namespace to temporarily store a
# redirect url value so that when a matching SAML response comes back from SSOe
# we know where to redirect the newly authenticated user.
class SAMLRequestTracker < Common::RedisStore
  redis_store REDIS_CONFIG[:saml_request_tracker][:namespace]
  redis_ttl REDIS_CONFIG[:saml_request_tracker][:each_ttl]
  redis_key :uuid

  attribute :uuid
  attribute :payload
  attribute :created_at

  validates :uuid, presence: true

  # Calculate the number of seconds that have elapsed since creation
  def age
    @created_at ? Time.new.to_i - @created_at : 0
  end

  def payload_attr(attr)
    @payload&.try(:[], attr)
  end

  def save
    @payload ||= {}
    @created_at ||= Time.new.to_i
    super
  end
end
