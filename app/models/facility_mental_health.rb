# frozen_string_literal: true

require 'common/models/redis_store'

class FacilityMentalHealth < Common::RedisStore
  redis_store REDIS_CONFIG['facility_mental_health']['namespace']
  redis_ttl REDIS_CONFIG['facility_mental_health']['each_ttl']
  redis_key :station_number

  attribute :station_number
  attribute :mh_phone
  attribute :mh_ext
  attribute :modified
  attribute :local_updated

  validates :station_number, presence: true
end
