# frozen_string_literal: true

require 'common/models/redis_store'

class FacilitySatisfaction < Common::RedisStore
  redis_store REDIS_CONFIG[:facility_access_satisfaction][:namespace]
  redis_ttl REDIS_CONFIG[:facility_access_satisfaction][:each_ttl]
  redis_key :station_number

  attribute :station_number
  attribute :metrics
  attribute :source_updated
  attribute :local_updated

  validates :station_number, presence: true
end
