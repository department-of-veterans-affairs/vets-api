class RateLimitedSearch < Common::RedisStore
  COUNT_LIMIT = 3

  redis_store(name.underscore)
  redis_ttl(86_400)
  redis_key(:search_params)

  attribute(:count, Integer, default: 1)
  attribute(:search_params, String)

  class RateLimitedError < StandardError
  end

  def self.create_or_increment_count(search_params)
    rate_limited_search = self.find(search_params)

    if rate_limited_search
      if rate_limited_search.count >= COUNT_LIMIT
        raise RateLimitedError
      end
      rate_limited_search.count += 1
      rate_limited_search.save!
    else
      self.create(search_params: search_params)
    end
  end
end
