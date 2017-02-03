# frozen_string_literal: true
require 'common/models/redis_store'

class Session < Common::RedisStore

  redis_store REDIS_CONFIG['session_store']['namespace']
  redis_ttl REDIS_CONFIG['session_store']['each_ttl']
  redis_key :token

  DEFAULT_TOKEN_LENGTH = 40
  MAX_SESSION_TTL = 12.hours

  attribute :token
  attribute :uuid
  attribute :created_at

  validates :token, presence: true
  validates :uuid, presence: true
  # validates other attributes?

  after_initialize :setup_defaults

  def self.obscure_token(token)
    Digest::SHA256.hexdigest(token)[0..20]
  end

  def save
    max_time_left = (@created_at + MAX_SESSION_TTL - Time.now.utc).round
    if max_time_left <= 0
      # bad - could theoretically happen though
    elsif max_time_left < redis_namespace_ttl
      super(max_time_left)
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
end
