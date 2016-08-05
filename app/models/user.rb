class User < RedisStore
  NAMESPACE = REDIS_CONFIG["user_store"]["namespace"]
  REDIS_STORE = Redis::Namespace.new(NAMESPACE, redis: Redis.current)
  DEFAULT_TTL = REDIS_CONFIG["user_store"]["each_ttl"]

  # id.me attributes
  attribute :uuid
  attribute :email
  attribute :first_name
  attribute :last_name
  attribute :zip

  # Add additional MVI attributes
  alias redis_key uuid

  validates :uuid, presence: true
  validates :email, presence: true
end
