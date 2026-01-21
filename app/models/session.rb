# frozen_string_literal: true

require 'common/models/redis_store'

class Session < Common::RedisStore
  redis_store REDIS_CONFIG[:session_store][:namespace]
  redis_ttl REDIS_CONFIG[:session_store][:each_ttl]
  redis_key :token

  DEFAULT_TOKEN_LENGTH = 40
  MAX_SESSION_LIFETIME = 12.hours

  attribute :token
  attribute :uuid
  attribute :created_at
  attribute :ssoe_transactionid
  attribute :profile
  attribute :charon_response
  attribute :launch
  # uuid no longer required as session may be for a system rather than a user
  attribute :uuid
  validates :token, presence: true
  validates :created_at, presence: true

  validate :within_maximum_ttl

  after_initialize :setup_defaults

  def self.obscure_token(token)
    Digest::SHA256.hexdigest(token)[0..20]
  end

  def expire(ttl)
    return false if invalid?

    super(ttl)
  end

  def ttl_in_time
    Time.current.utc + ttl
  end

  def authenticated_by_ssoe
    @ssoe_transactionid.present?
  end

  private

  def secure_random_token(length = DEFAULT_TOKEN_LENGTH)
    loop do
      # copied from: https://github.com/plataformatec/devise/blob/master/lib/devise.rb#L475-L482
      rlength = (length * 3) / 4
      random_token = SecureRandom.urlsafe_base64(rlength).tr('lIO0', 'sxyz')
      break random_token unless self.class.exists?(random_token) == 1
    end
  end

  def setup_defaults
    @token ||= secure_random_token
    @created_at ||= Time.now.utc
  end

  def within_maximum_ttl
    time_remaining = (@created_at + MAX_SESSION_LIFETIME - Time.now.utc).round
    if time_remaining.negative?
      Rails.logger.info('[Session] Maximum Session Duration Reached',
                        session_token: self.class.obscure_token(@token))
      errors.add(:created_at, "is more than the max of [#{MAX_SESSION_LIFETIME}] seconds. Session is too old")
    end
  end
end
