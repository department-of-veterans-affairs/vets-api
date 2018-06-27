# frozen_string_literal: true

require 'common/models/redis_store'

class MHVAccountIneligible < Common::RedisStore
  redis_store REDIS_CONFIG['mhv_account_ineligible']['namespace']
  redis_ttl REDIS_CONFIG['mhv_account_ineligible']['each_ttl']
  redis_key :uuid

  attribute :uuid
  attribute :account_state
  attribute :mhv_correlation_id
  attribute :icn

  validates :uuid, presence: true
end
