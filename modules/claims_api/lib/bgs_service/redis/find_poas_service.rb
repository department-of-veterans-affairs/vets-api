# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'
require 'bgs_service/standard_data_web_service'
require 'bgs_service/redis/find_poas_response'

module ClaimsApi
  class FindPOAsService < ::Common::RedisStore
    include ::Common::CacheAside

    redis_config_key :bgs_find_poas_response

    def response
      @response ||= response_from_redis_or_service.response
    end

    private

    def todays_date
      Time.zone.now.to_date.to_s
    end

    def response_from_redis_or_service
      do_cached_with(key: todays_date) do
        response = standard_data_web_service.find_poas

        ClaimsApi::FindPOAsResponse.new(filter_response(response))
      end
    end

    def filter_response(response)
      response.map { |poa| poa.slice(:legacy_poa_cd, :ptcpnt_id) }
    end

    def standard_data_web_service
      @service ||= ClaimsApi::StandardDataWebService.new(external_uid: 'find_poas_service_uid',
                                                         external_key: 'find_poas_service_key')
    end
  end
end
