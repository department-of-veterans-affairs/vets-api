# frozen_string_literal: true
require 'common/models/base'
require 'common/models/redis_store'
require 'mvi/messages/find_candidate_message'
require 'mvi/service'
require 'evss/common_service'
require 'evss/auth_headers'
require 'saml/user_attributes'

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
  attribute :loa

  # vaafi attributes
  attribute :last_signed_in, Common::UTCTime

  # mhv_last_signed_in used to determine whether we need to notify MHV audit logging
  # This is set to Time.now when any MHV session is first created, and nulled, when logout
  attribute :mhv_last_signed_in, Common::UTCTime

  validates :uuid, presence: true
  validates :email, presence: true
  validates :loa, presence: true

  # conditionally validate if user is LOA3
  with_options(on: :loa3_user) do |user|
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

  def can_access_user_profile?
    loa1? || loa2? || loa3?
  end

  def can_access_mhv?
    loa3? && mhv_correlation_id
  end

  def can_access_evss?
    edipi.present? && ssn.present? && participant_id.present?
  end

  def self.from_merged_attrs(existing_user, new_user)
    # we want to always use the more recent attrs so long as they exist
    attrs = new_user.attributes.map do |key, val|
      { key => val.presence || existing_user[key] }
    end.reduce({}, :merge)

    # for loa, we want the higher of the two
    attrs[:loa][:current] = [existing_user[:loa][:current], new_user[:loa][:current]].max
    attrs[:loa][:highest] = [existing_user[:loa][:highest], new_user[:loa][:highest]].max

    User.new(attrs)
  end

  def self.from_saml(saml_response)
    User.new(SAML::UserAttributes.new(saml_response))
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
end
