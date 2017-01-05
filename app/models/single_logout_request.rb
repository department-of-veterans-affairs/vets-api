# frozen_string_literal: true
require 'common/models/redis_store'

class SingleLogoutRequest < Common::RedisStore
  redis_store REDIS_CONFIG['saml_store']['namespace']
  redis_ttl REDIS_CONFIG['saml_store']['each_ttl']
  redis_key :uuid

  attribute :uuid
  attribute :token

  validates :uuid, presence: true
  validates :token, presence: true
end
