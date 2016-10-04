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

  # id.me attributes
  attribute :uuid
  attribute :email
  attribute :first_name
  attribute :middle_name
  attribute :last_name
  attribute :gender
  attribute :birth_date, Common::UTCTime
  attribute :zip
  attribute :ssn

  # id.me returned loa
  attribute :level_of_assurance

  # vaafi attributes
  attribute :last_signed_in, Common::UTCTime
  attribute :edipi
  attribute :participant_id
  attribute :ssn

  # mvi 'golden record' data
  attribute :mvi

  validates :uuid, presence: true
  validates :email, presence: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :birth_date, presence: true
  validates :ssn, presence: true

  def rating_record
    client = EVSS::CommonService.new(self)
    client.find_rating_info.body.fetch('ratingRecord', {})
  end

  # TODO(AJD): realize this is temporary but it's also used in specs where it should be stubbed or a factory
  def self.sample_claimant
    attrs = JSON.load(ENV['EVSS_SAMPLE_CLAIMANT_USER'])
    attrs[:last_signed_in] = Time.now.utc
    User.new attrs
  end
end
