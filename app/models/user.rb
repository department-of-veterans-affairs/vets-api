# frozen_string_literal: true
require 'common/models/base'
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
  attribute :dob
  attribute :zip

  # vaafi/mvi attributes
  attribute :last_signed_in, Common::UTCTime
  attribute :edipi
  attribute :icn
  attribute :mhv_id
  attribute :participant_id
  attribute :ssn

  # Add additional MVI attributes
  alias redis_key uuid

  validates :uuid, presence: true
  validates :email, presence: true

  after_initialize :fetch_mvi_data

  def self.sample_claimant
    attrs = JSON.load(ENV['EVSS_SAMPLE_CLAIMANT_USER'])
    attrs[:last_signed_in] = Time.now.utc
    User.new attrs
  end

  def fetch_mvi_data
    unless mvi_ids?
      message = MVI::Messages::FindCandidateMessage.new(
        [first_name, middle_name],
        last_name,
        dob,
        ssn,
        gender
      )
      response = MVI::Service.find_candidate(message)
      self.edipi = response[:edipi]
      self.icn = response[:icn]
      self.mhv_id = response[:mhv_id]
      save
    end
  rescue MVI::ServiceError => e
    logger.error "service error: #{e.message} retrieving MVI data for user: #{uuid}"
  end

  def mvi_ids?
    [edipi, icn, mhv_id].all? { |id| !id.nil? }
  end
end
