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
  attribute :birth_date
  attribute :zip
  attribute :ssn
  attribute :loa_highest

  # vaafi attributes
  attribute :last_signed_in, Common::UTCTime

  # mhv_last_signed_in used to determine whether we need to notify MHV audit logging
  # This is set to Time.now when any MHV session is first created, and nulled, when logout
  attribute :mhv_last_signed_in, Common::UTCTime

  validates :uuid, presence: true
  validates :email, presence: true

  # conditionally validate if user is LOA3
  with_options(on: :loa3_user) do |user|
    user.validates :first_name, presence: true
    user.validates :last_name, presence: true
    user.validates :birth_date, presence: true
    user.validates :ssn, presence: true, format: /\A\d{9}\z/
    user.validates :gender, format: /\A(M|F)\z/, allow_blank: true
  end

  def rating_record
    client = EVSS::CommonService.new(evss_auth_headers)
    client.find_rating_info(participant_id).body.fetch('ratingRecord', {})
  end

  # This is a helper method for pulling mhv_correlation_id
  def mhv_correlation_id
    mhv_correlation_ids.first
  end

  def can_access_user_profile?(session)
    session.loa1? || session.loa2? || session.loa3?
  end

  def can_access_mhv?(session)
    session.loa3? && mhv_correlation_id
  end

  def can_access_evss?
    # TODO : this should have a session.loa3 check.  Although,
    # ssn.present? acts as an implicit session.loa3? check
    edipi.present? && ssn.present? && participant_id.present?
  end

  delegate :edipi, to: :mvi
  delegate :icn, to: :mvi
  delegate :mhv_correlation_id, to: :mvi
  delegate :participant_id, to: :mvi
  delegate :va_profile, to: :mvi

  private

  def mvi
    @mvi ||= Mvi.from_user(self)
  end

  def evss_auth_headers
    @evss_auth_headers ||= EVSS::AuthHeaders.new(self).to_h
  end
end
