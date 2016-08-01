class Session
  include ActiveModel::Model
  include Virtus.model
  HOURS_TO_EXPIRE = 10
  SESSION_STORE = Redis::Namespace.new("vets-api-session", redis: Redis.current).freeze

  attribute :token
  attribute :expires_at
  attribute :persisted
  # Other attributes

  validates :token, presence: true, if: Proc.new { |s| s.persisted? }
  validates :expires_at, presence: true, if: Proc.new { |s| s.persisted? }
  #validates other attributes?

  def self.find(token = nil)
    attributes = SESSION_STORE.hgetall(token).with_indifferent_access
    session = Session.new(attributes.merge(persisted: true))
    return session if session.valid?
    SESSION_STORE.del(token)
    raise ActiveRecord::RecordNotFound # raise a better error than this
  end

  def self.exists?(token = nil)
    SESSION_STORE.exists(token)
  end

  def save
    @expires_at = HOURS_TO_EXPIRE.hours.from_now.utc
    @token = secure_random_token #use bcrypt or something to generate unique token
    return false unless valid?
    result = SESSION_STORE.mapped_hmset(token, attributes)
    @persisted = result == "OK"
  end

  def persisted?
    !!@persisted
  end

  private

  def secure_random_token
    loop do
      # TODO: MAKE THIS LONGER AND MORE SECURE
      # currently like: "R90Gfo8Eme2KApnh2tDP9A"
      random_token = SecureRandom.urlsafe_base64(nil, false)
      break random_token unless self.class.exists?(random_token)
    end
  end
end
