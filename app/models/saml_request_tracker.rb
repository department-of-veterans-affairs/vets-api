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
  redis_store REDIS_CONFIG['login_redirect_application']['namespace']
  redis_ttl REDIS_CONFIG['login_redirect_application']['each_ttl']
  redis_key :uuid

  attribute :uuid
  attribute :payload
  attribute :created_at

  validates :uuid, presence: true

  # Find the payload attribute for the record with the matching UUID,
  # if no record is found, or the attribute is missing, return NilClass
  def self.safe_payload_attr(uuid, attr)
    uuid && find(uuid)&.payload.try(:[], attr)
  end

  # Calculate the age, in seconds, of the matching SAML Request Tracker record.
  # If no record can be found, return NilClass
  def self.age(uuid)
    created_at = find(uuid)&.created_at

    Time.new.to_i - created_at if created_at
  end

  def save
    @payload ||= {}
    @created_at ||= Time.new.to_i
    super
  end
end
