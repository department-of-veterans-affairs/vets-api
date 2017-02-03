# frozen_string_literal: true
require 'common/models/redis_store'

class Session < Common::RedisStore
  redis_store REDIS_CONFIG['session_store']['namespace']
  redis_ttl REDIS_CONFIG['session_store']['each_ttl']
  redis_key :token

  DEFAULT_TOKEN_LENGTH = 40
  MAX_SESSION_TTL      = 12.hours

  attribute :token
  attribute :uuid
  attribute :created_at

  validates :token, presence: true
  validates :uuid, presence: true
  validates :created_at, presence: true

  validate :within_maximum_ttl?
  # validates other attributes?

  after_initialize :setup_defaults

  def self.obscure_token(token)
    Digest::SHA256.hexdigest(token)[0..20]
  end

  def save
    time_left = max_ttl
    if time_left < redis_namespace_ttl
      super(time_left)
    else
      super
    end
  end

  private

  def secure_random_token(length = DEFAULT_TOKEN_LENGTH)
    loop do
      # copied from: https://github.com/plataformatec/devise/blob/master/lib/devise.rb#L475-L482
      rlength = (length * 3) / 4
      random_token = SecureRandom.urlsafe_base64(rlength).tr('lIO0', 'sxyz')
      break random_token unless self.class.exists?(random_token)
    end
  end

  def setup_defaults
    unless persisted?
      @token ||= secure_random_token
      @created_at ||= Time.now.utc
    end
  end

  def max_ttl
    (@created_at + MAX_SESSION_TTL - Time.now.utc).round
  end

  def within_maximum_ttl?
    if max_ttl.negative?
      errors.add(:created_at, "is more than the max of [#{MAX_SESSION_TTL}] ago. Session is too old")
    end
  end
end
