# frozen_string_literal: true
require 'common/models/base'
require 'common/models/redis_store'
require 'mvi/messages/find_candidate_message'
require 'mvi/service'
require 'evss/common_service'
require 'evss/auth_headers'

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
  attribute :loa

  # vaafi attributes
  attribute :last_signed_in, Common::UTCTime
  # Electronic data interchange personal identifier, aka DoD ID
  # https://en.wikipedia.org/wiki/Defense_Enrollment_Eligibility_Reporting_System#Electronic_data_interchange_personal_identifier
  attribute :edipi
  attribute :participant_id
  attribute :icn

  # mvi 'golden record' data
  attribute :mvi

  # mhv_last_signed_in used to determine whether we need to notify MHV audit logging
  # This is set to Time.now when any MHV session is first created, and nulled, when logout
  attribute :mhv_last_signed_in, Common::UTCTime

  validates :uuid, presence: true
  validates :email, presence: true
  validates :loa, presence: true

  # conditionally validate if user is LOA3
  with_options unless: :loa1? do |user|
    user.validates :first_name, presence: true
    user.validates :last_name, presence: true
    user.validates :birth_date, presence: true
    user.validates :ssn, presence: true, format: /\A\d{9}\z/
    user.validates :gender, format: /\A(M|F)\z/, allow_blank: true
  end

  def loa1?
    loa[:current] == LOA::ONE
  end

  def loa2?
    loa[:current] == LOA::TWO
  end

  def loa3?
    loa[:current] == LOA::THREE
  end

  def rating_record
    client = EVSS::CommonService.new(evss_auth_headers)
    client.find_rating_info(participant_id).body.fetch('ratingRecord', {})
  end

  # This is a helper method for pulling mhv_correlation_id
  def mhv_correlation_ids
    @mhv_correlation_ids ||= mvi&.fetch(:mhv_ids, [])
                                 .map { |mhv_id| mhv_id.split('^')&.first }
                                 .compact
  end

  def can_access_user_profile?
    loa1? || loa2? || loa3?
  end

  def can_access_mhv?
    loa3? && mhv_correlation_ids.length == 1
  end

  def can_access_evss?
    edipi.present? && ssn.present? && participant_id.present?
  end

  private

  def evss_auth_headers
    @evss_auth_headers ||= EVSS::AuthHeaders.new(self).to_h
  end
end
