# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'
require 'emis/military_information_service_v2'

module EMISRedis
  # Generic model for caching EMIS data in Redis
  class Model < Common::RedisStore
    include Common::CacheAside

    attr_accessor :user

    # @param user [User] User object
    # @return [EMISRedis::Model] A new +EMISRedis::Model+
    #  for fetching the passed in user's EMIS data
    def self.for_user(user)
      redis_config_key(:emis_response)

      emis_model = new
      emis_model.user = user
      emis_model
    end

    private

    def items_from_response(method)
      emis_response(method)&.items || []
    end

    def emis_response(method)
      @emis_response ||= {}

      @emis_response[method] ||= lambda do
        response = response_from_redis_or_service(method)
        raise response.error if response.error?

        response
      end.call
    end

    def response_from_redis_or_service(method)
      do_cached_with(key: "#{@user.uuid}.#{class_name}.#{method}") do
        raise ArgumentError, 'could not make eMIS call, user has no edipi or icn' unless @user.edipi || @user.icn

        options = {}
        @user.edipi ? options[:edipi] = @user.edipi : options[:icn] = @user.icn
        service.public_send(method, **options)
      end
    end

    def class_name
      self.class::CLASS_NAME
    end

    def service
      @service ||= "EMIS::#{class_name}".constantize.new
    end
  end
end
