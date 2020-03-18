# frozen_string_literal: true

require 'common/models/redis_store'

class LoginRedirectApplication < Common::RedisStore
  redis_store REDIS_CONFIG['login_redirect_application']['namespace']
  redis_ttl REDIS_CONFIG['login_redirect_application']['each_ttl']
  redis_key :uuid

  attribute :uuid
  attribute :redirect_application

  validates :uuid, presence: true
  validates :redirect_application, presence: true
end
