# frozen_string_literal: true

require 'common/models/redis_store'

module ClaimsApi
  class BRDResponseStore < ::Common::RedisStore
    redis_store REDIS_CONFIG[:brd_response_store][:namespace]
    redis_ttl REDIS_CONFIG[:brd_response_store][:each_ttl]
    redis_key :service_name

    TOLERANCE = 5

    attribute :service_name, String
    attribute :response, String

    validates(:response, presence: true)

    def self.set_brd_response(service_name, response, ttl = redis_namespace_ttl)
      service = new(service_name:)
      service.response = response
      service.save!

      service.expire(ttl - TOLERANCE)
    end

    def self.get_brd_response(service_name)
      service = find(service_name)
      service&.response
    end
  end
end
