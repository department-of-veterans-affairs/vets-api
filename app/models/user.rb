# frozen_string_literal: true
require 'common/models/base'

class User < RedisStore
  redis_store REDIS_CONFIG['user_store']['namespace']
  default_ttl REDIS_CONFIG['user_store']['each_ttl']

  # id.me attributes
  attribute :uuid
  attribute :email
  attribute :first_name
  attribute :last_name
  attribute :zip

  # vaafi attributes
  attribute :last_signed_in, Common::UTCTime
  attribute :edipi
  attribute :participant_id
  attribute :ssn

  # Add additional MVI attributes
  alias redis_key uuid

  validates :uuid, presence: true
  validates :email, presence: true

  def self.sample_claimant
    attrs = JSON.load(ENV['EVSS_SAMPLE_CLAIMANT_USER'])
    attrs[:last_signed_in] = Time.now.utc
    User.new attrs
  end
end
