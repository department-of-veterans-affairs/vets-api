# frozen_string_literal: true

require 'common/models/redis_store'

class FacilityDentalService < Common::RedisStore
  redis_store REDIS_CONFIG['facility_dental_service']['namespace']
  redis_ttl REDIS_CONFIG['facility_dental_service']['each_ttl']
  redis_key :station_number

  attribute :station_number
  attribute :local_updated

  validates :station_number, presence: true
end
