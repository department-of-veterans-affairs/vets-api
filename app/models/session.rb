class Session
  include ActiveModel::Model
  include Virtus.model
  NAMESPACE = REDIS_CONFIG["redis_namespaces"]["session_store"]["namespace"]
  SESSION_STORE = Redis::Namespace.new(NAMESPACE, redis: Redis.current)
  DEFAULT_TTL = REDIS_CONFIG["redis_namespaces"]["session_store"]["each_ttl"]
  DEFAULT_TOKEN_LENGTH = 40

  attribute :token
  # Other attributes

  attr_accessor :persisted

  validates :token, presence: true
  # validates other attributes?

  def initialize(attributes = {}, persisted = false)
    super(attributes)
    @persisted = persisted
    @token ||= secure_random_token unless persisted?
  end

  def self.find(token = nil)
    attributes = SESSION_STORE.hgetall(token).with_indifferent_access
    return nil if attributes.blank?
    session = Session.new(attributes, true)
    if session.valid?
      session
    else
      SESSION_STORE.del(token)
      nil
    end
  end

  def self.exists?(token = nil)
    SESSION_STORE.exists(token)
  end

  def save
    return false unless valid?
    SESSION_STORE.mapped_hmset(token, attributes)
    SESSION_STORE.expire(token, DEFAULT_TTL)
    @persisted = true
  end

  def ttl
    SESSION_STORE.ttl(@token)
  end

  def persisted?
    @persisted == true
  end

  private

  def secure_random_token(length = DEFAULT_TOKEN_LENGTH)
    loop do
      # copied from: https://github.com/plataformatec/devise/blob/master/lib/devise.rb#L475-L482
      rlength = (length * 3) / 4
      random_token = SecureRandom.urlsafe_base64(rlength).tr("lIO0", "sxyz")
      break random_token unless self.class.exists?(random_token)
    end
  end
end
