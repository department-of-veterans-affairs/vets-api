# frozen_string_literal: true
require 'common/models/redis_store'

class Session < Common::RedisStore
  redis_store REDIS_CONFIG['session_store']['namespace']
  default_ttl REDIS_CONFIG['session_store']['each_ttl']

  DEFAULT_TOKEN_LENGTH = 40

  attribute :token
  attribute :uuid
  # Other attributes
  alias redis_key token

  validates :token, presence: true
  # validates other attributes?

  after_initialize :setup_defaults

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
