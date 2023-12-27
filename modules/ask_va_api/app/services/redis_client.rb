# frozen_string_literal: true

class RedisClient
  def token
    Rails.cache.read(
      'token',
      namespace: 'crm-api-cache'
    )
  end

  def cache_data(data:, name:)
    Rails.cache.write(
      name,
      data,
      namespace: 'crm-api-cache',
      expires_in: 3540
    )
  end
end
