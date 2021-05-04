# frozen_string_literal: true

require 'common/models/concerns/cache_aside'
require 'gi/client'
require 'gi/search_client'

# Facade for GIDS.
class GIDSRedis < Common::RedisStore
  include Common::CacheAside

  redis_config_key :gids_response

  # @return  [Symbol] the GI::Client method to call
  attr_accessor :rest_call

  # @return [Hash] the params to be used with the rest_call
  attr_accessor :scrubbed_params

  def method_missing(name, *args)
    self.rest_call = name
    self.scrubbed_params = args.first

    if scrubbed_params[:v1]

      if respond_to_missing_v1?(name)
        response_from_redis_or_service(gi_service).body
      elsif search_respond_to_v1?(name)
        response_from_redis_or_service(gi_search_service).body
      else
        super
      end

    else

      if respond_to?(name)
        response_from_redis_or_service(gi_service).body
      elsif search_respond_to?(name)
        response_from_redis_or_service(gi_search_service).body
      else
        super
      end
    end
  end

  def respond_to_missing?(name, _include_private)
    gi_service.respond_to?(name)
  end

  def search_respond_to?(name)
    gi_search_service.respond_to?(name)
  end

  def respond_to_missing_v1?(name)
    gi_service_v1.respond_to?(name)
  end

  def search_respond_to_v1?(name)
    gi_search_service_v1.respond_to?(name)
  end

  private

  def response_from_redis_or_service(service)
    do_cached_with(key: rest_call.to_s + scrubbed_params.to_s) do
      service.send(rest_call, scrubbed_params)
    end
  end

  def gi_service
    @client ||= ::GI::Client.new
  end

  def gi_search_service
    @search_client ||= ::GI::SearchClient.new
  end

  def gi_service_v1
    @client ||= ::GI::V1::Client.new
  end

  def gi_search_service_v1
    @search_client ||= ::GI::V1::SearchClient.new
  end
end
