# frozen_string_literal: true
require 'common/models/base'
require 'common/exceptions'
require 'mvi/messages/find_candidate_message'
require 'mvi/service'

class User < RedisStore
  NAMESPACE = REDIS_CONFIG['user_store']['namespace']
  REDIS_STORE = Redis::Namespace.new(NAMESPACE, redis: Redis.current)
  DEFAULT_TTL = REDIS_CONFIG['user_store']['each_ttl']

  # id.me attributes
  attribute :uuid
  attribute :email
  attribute :first_name
  attribute :middle_name
  attribute :last_name
  attribute :gender
  attribute :dob, Common::UTCTime
  attribute :zip

  # vaafi attributes
  attribute :last_signed_in, Common::UTCTime
  attribute :edipi
  attribute :participant_id
  attribute :ssn

  # Add additional MVI attributes
  alias redis_key uuid

  # mvi 'golden record' data
  attribute :mvi

  validates_presence_of :uuid, :email, :first_name, :last_name, :dob, :ssn

  # TODO(AJD): realize this is temporary but it's also used in specs where it should be stubbed or a factory
  def self.sample_claimant
    attrs = JSON.load(ENV['EVSS_SAMPLE_CLAIMANT_USER'])
    attrs[:last_signed_in] = Time.now.utc
    User.new attrs
  end
end
