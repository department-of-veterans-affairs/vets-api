# frozen_string_literal: true

class RateLimitedSearch < Common::RedisStore
  COUNT_LIMIT = 3

  redis_store(name.underscore)
  redis_ttl(86_400)
  redis_key(:search_params)

  attribute(:count, Integer, default: 1)
  attribute(:search_params, String)

  class RateLimitedError < Common::Exceptions::TooManyRequests
  end

  def self.create_or_increment_count(search_params)
    hashed_params = Digest::SHA2.hexdigest(search_params)

    rate_limited_search = find(hashed_params)

    if rate_limited_search
      raise RateLimitedError if rate_limited_search.count >= COUNT_LIMIT
      rate_limited_search.count += 1
      rate_limited_search.save!
    else
      create(search_params: hashed_params)
    end
  end
end
