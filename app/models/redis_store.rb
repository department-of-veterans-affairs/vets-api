class RedisStore
  extend ActiveModel::Naming
  extend ActiveModel::Callbacks
  define_model_callbacks :initialize, only: :after

  include ActiveModel::Serialization
  include ActiveModel::Validations
  include ActiveModel::Conversion
  include Virtus.model
  REDIS_STORE = Redis.current

  def initialize(attributes = {}, persisted = false)
    super(attributes)
    @persisted = persisted
    run_callbacks :initialize
  end

  def self.find(redis_key = nil)
    attributes = REDIS_STORE.hgetall(redis_key).with_indifferent_access
    return nil if attributes.blank?
    object = new(attributes, true)
    if object.valid?
      object
    else
      REDIS_STORE.del(redis_key)
      nil
    end
  end

  def self.exists?(redis_key = nil)
    REDIS_STORE.exists(redis_key)
  end

  def save
    return false unless valid?
    REDIS_STORE.mapped_hmset(redis_key, attributes)
    REDIS_STORE.expire(redis_key, self.class::DEFAULT_TTL) if defined? self.class::DEFAULT_TTL
    @persisted = true
  end

  def ttl
    REDIS_STORE.ttl(redis_key)
  end

  def persisted?
    @persisted == true
  end
end
