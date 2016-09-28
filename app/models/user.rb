# frozen_string_literal: true
require 'common/models/base'
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

  # vaafi/mvi attributes
  attribute :last_signed_in, Common::UTCTime
  attribute :edipi
  attribute :participant_id
  attribute :ssn

  # Add additional MVI attributes
  alias redis_key uuid

  # mvi 'golden record' data
  attribute :mvi_edipi
  attribute :mvi_icn
  attribute :mvi_mhv_id
  attribute :mvi_given_names
  attribute :mvi_family_name
  attribute :mvi_gender
  attribute :mvi_dob
  attribute :mvi_ssn

  validates :uuid, presence: true
  validates :email, presence: true

  after_initialize :fetch_mvi_data

  def self.sample_claimant
    attrs = JSON.load(ENV['EVSS_SAMPLE_CLAIMANT_USER'])
    attrs[:last_signed_in] = Time.now.utc
    User.new attrs
  end

  def fetch_mvi_data
    message = MVI::Messages::FindCandidateMessage.new(
      [first_name, middle_name],
      last_name,
      dob,
      ssn,
      gender
    )
    if message.valid?
      response = MVI_SERVICE.find_candidate(message)
      update(Hash[response.map { |k, v| ["mvi_#{k}".to_sym, v] }])
    else
      errors = message.errors.full_messages.join(', ')
      Rails.logger.warn "MVI user data not retrieved: invalid message: #{errors}"
    end
  rescue MVI::ServiceError => e
    Rails.logger.error "MVI user data not retrieved: service error: #{e.message} for user: #{uuid}"
  end
end
