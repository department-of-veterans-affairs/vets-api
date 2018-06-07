# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

module Vet360Redis
  # Facade for Vet360::ReferenceData::Service. The user_serializer delegates
  # to this class through the User model.
  #
  # When a person is requested from the serializer, it returns either a cached
  # response in Redis or from the Vet360::ContactInformation::Service.
  #
  class ReferenceData < Common::RedisStore
    include Common::CacheAside

    # Redis settings for ttl and namespacing reside in config/redis.yml
    redis_config_key :vet360_reference_data_response

    def countries
      response_from_redis_or_service(:countries).reference_data
    end

    def states
      response_from_redis_or_service(:states).reference_data
    end

    def zipcodes
      response_from_redis_or_service(:zipcodes).reference_data
    end

    private

    def response_from_redis_or_service(endpoint)
      do_cached_with(key: "vet360_reference_data_#{endpoint}") do
        reference_data_service.public_send(endpoint)
      end
    end

    def reference_data_service
      @service ||= Vet360::ReferenceData::Service.new(nil)
    end
  end
end
