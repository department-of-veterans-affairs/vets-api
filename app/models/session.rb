class Session
  include ActiveModel::Model
  include Virtus.model
  NAMESPACE = REDIS_CONFIG["redis_namespaces"]["session_store"]["namespace"]
  TTL = REDIS_CONFIG["redis_namespaces"]["session_store"]["each_ttl"]

  attribute :token
  attribute :ttl
  # Other attributes

  attribute_accessor :persisted

  validates :token, presence: true, if: proc { |s| s.persisted? }
  validates :ttl, presence: true, if: proc { |s| s.persisted? }
  # validates other attributes?

  def self.find(token = nil)
    attributes = session_store.hgetall(token).with_indifferent_access
    session = Session.new(attributes.merge(persisted: true))
    return session if session.valid?
    session_store.del(token)
    fail ActiveRecord::RecordNotFound # raise a better error than this
  end

  def self.exists?(token = nil)
    session_store.exists(token)
  end

  def save
    @ttl = TTL
    @token = secure_random_token # use bcrypt or something to generate unique token
    return false unless valid?
    result = session_store.mapped_hmset(token, attributes)
    session_store.expire(token, TTL)
    @persisted = result == "OK"
  end

  def persisted?
    Boolean(@persisted)
  end

  private

  def session_store
    @session_store ||= Redis::Namespace.new(NAMESPACE, redis: Redis.current)
  end

  def secure_random_token(length = 20)
    loop do
      # copied from: https://github.com/plataformatec/devise/blob/master/lib/devise.rb#L475-L482
      rlength = (length * 3) / 4
      SecureRandom.urlsafe_base64(rlength).tr("lIO0", "sxyz")
      break random_token unless self.class.exists?(random_token)
    end
  end
end
