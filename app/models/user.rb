# frozen_string_literal: true
require 'common/models/base'
require 'common/exceptions'
require 'mvi/messages/find_candidate_message'
require 'mvi/service'

class User < RedisStore
  NAMESPACE = REDIS_CONFIG['user_store']['namespace']
  REDIS_STORE = Redis::Namespace.new(NAMESPACE, redis: Redis.current)
  DEFAULT_TTL = REDIS_CONFIG['user_store']['each_ttl']
  MVI_SERVICE = VetsAPI::Application.config.mvi_service

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

  validates :uuid, presence: true
  validates :email, presence: true

  after_initialize :fetch_mvi_data

  def self.sample_claimant
    attrs = JSON.load(ENV['EVSS_SAMPLE_CLAIMANT_USER'])
    attrs[:last_signed_in] = Time.now.utc
    User.new attrs
  end

  def fetch_mvi_data
    given_names = [first_name]
    given_names.push middle_name unless middle_name.nil?
    message = MVI::Messages::FindCandidateMessage.new(
      given_names,
      last_name,
      dob,
      ssn,
      gender
    )
    if message.valid?
      response = MVI_SERVICE.find_candidate(message)
      update(mvi: response)
    else
      raise Common::Exceptions::ValidationErrors, message
    end
  rescue MVI::ServiceError => e
    # TODO(AJD): add cloud watch metric
    Rails.logger.error "MVI user data not retrieved: service error: #{e.message} for user: #{uuid}"
    raise Common::Exceptions::RecordNotFound, "Failed to retrieve MVI data: #{e.message}"
  end
end
