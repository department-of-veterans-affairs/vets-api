# frozen_string_literal: true
require 'common/models/redis_store'

class Session < Common::RedisStore
  redis_store REDIS_CONFIG['session_store']['namespace']
  redis_ttl REDIS_CONFIG['session_store']['each_ttl']
  redis_key :token

  DEFAULT_TOKEN_LENGTH = 40

  attribute :token
  attribute :uuid
  attribute :level

  validates :token, presence: true
  validates :level, presence: true, inclusion: { in: [LOA::ONE, LOA::TWO, LOA::THREE] }
  # validates other attributes?

  after_initialize :setup_defaults

  def loa1?
    level == LOA::ONE
  end

  def loa2?
    level == LOA::TWO
  end

  def loa3?
    level == LOA::THREE
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
    @token ||= secure_random_token unless persisted?
  end
end
