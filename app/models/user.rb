# frozen_string_literal: true
require 'common/models/base'
require 'common/models/redis_store'
require_dependency 'evss/common_service'
require 'mvi/messages/find_candidate_message'
require 'mvi/service'

class User < Common::RedisStore
  redis_store REDIS_CONFIG['user_store']['namespace']
  redis_ttl REDIS_CONFIG['user_store']['each_ttl']
  redis_key :uuid

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
  attribute :ssn
  attribute :birth_date

  # id.me returned loa
  attribute :level_of_assurance

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

  def rating_record
    client = EVSS::CommonService.new(self)
    client.find_rating_info.body.fetch('ratingRecord', {})
  end

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
      errors = message.errors.full_messages.join(', ')
      Rails.logger.warn "MVI user data not retrieved: invalid message: #{errors}"
    end
  rescue MVI::ServiceError => e
    Rails.logger.error "MVI user data not retrieved: service error: #{e.message} for user: #{uuid}"
  end
end
