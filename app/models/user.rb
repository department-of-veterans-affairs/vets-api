# frozen_string_literal: true
require 'common/models/base'
require 'common/models/redis_store'
require 'mvi/messages/find_candidate_message'
require 'mvi/service'
require_dependency 'evss/common_service'
require_dependency 'evss/auth_headers'

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
  # Electronic data interchange personal identifier, aka DoD ID
  # https://en.wikipedia.org/wiki/Defense_Enrollment_Eligibility_Reporting_System#Electronic_data_interchange_personal_identifier
  attribute :edipi
  attribute :participant_id
  attribute :mhv_id
  attribute :icn

  # mvi 'golden record' data
  attribute :mvi

  validates :uuid, presence: true
  validates :email, presence: true

  # conditionally validate if user is LOA3
  with_options if: :loa3? do |user|
    user.validates :first_name, presence: true
    user.validates :last_name, presence: true
    user.validates :birth_date, presence: true
    user.validates :ssn, presence: true, format: /\A\d{9}\z/
  end

  # TODO(AJD): realize this is temporary but it's also used in specs where it should be stubbed or a factory
  def self.sample_claimant
    attrs = JSON.load(ENV['EVSS_SAMPLE_CLAIMANT_USER'])
    attrs[:last_signed_in] = Time.now.utc
    User.new attrs
  end

  def loa3?
    level_of_assurance == LOA::THREE
  end

  def rating_record
    client = EVSS::CommonService.new(evss_auth_headers)
    client.find_rating_info(participant_id).body.fetch('ratingRecord', {})
  end

  private

  def evss_auth_headers
    @evss_auth_headers ||= EVSS::AuthHeaders.new(self).to_h
  end
end
