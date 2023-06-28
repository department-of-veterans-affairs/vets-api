# frozen_string_literal: true

require 'common/models/base'
require 'common/models/redis_store'

class IdentifierIndex < Common::RedisStore
  redis_store REDIS_CONFIG[:identifier_store][:namespace]
  redis_ttl REDIS_CONFIG[:identifier_store][:each_ttl]
  redis_key :identifier

  attribute :identifier
  attribute :email_address

  validates :identifier, presence: true
end
