module Common
  module Cache
    module RedisCachable
      extend ActiveSupport::Concern

      attr_accessor :redis, :default_ttl

      def cache(key)
        if (value = redis.get(key)).nil?
          value = yield(self)
          redis.set(key, Oj.dump(value, mode: :compat))
          redis.expire(key, default_ttl)
          value
        else
          Oj.load(value)
        end
      end
    end
  end
end
