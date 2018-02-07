# frozen_string_literal: true

require 'common/models/base'
require 'common/models/redis_store'
require 'mvi/messages/find_profile_message'
require 'mvi/service'
require 'evss/common_service'
require 'evss/auth_headers'
require 'saml/user'

class User < Common::RedisStore
  include BetaSwitch

  UNALLOCATED_SSN_PREFIX = '796' # most test accounts use this

  # Defined per issue #6042
  ID_CARD_ALLOWED_STATUSES = %w[V1 V3 V6].freeze

  redis_store REDIS_CONFIG['user_b_store']['namespace']
  redis_ttl REDIS_CONFIG['user_b_store']['each_ttl']
  redis_key :uuid

  validates :uuid, presence: true

  # conditionally validate if user is LOA3
  with_options if: :loa3? do |loa3_user|
    loa3_user.validates :first_name, presence: true
    loa3_user.validates :last_name, presence: true
    loa3_user.validates :birth_date, presence: true
    loa3_user.validates :ssn, presence: true, format: /\A\d{9}\z/
    loa3_user.validates :gender, format: /\A(M|F)\z/, allow_blank: true
  end

  attribute :uuid
  attribute :last_signed_in, Common::UTCTime # vaafi attributes
  attribute :mhv_last_signed_in, Common::UTCTime # MHV audit logging

  # identity attributes, some of these will be overridden by MVI.
  delegate :email, to: :identity, allow_nil: true
  delegate :first_name, to: :identity, allow_nil: true

  def first_name
    identity.first_name || (mhv_icn.present? ? mvi&.profile&.given_names&.first : nil)
  end

  def middle_name
    identity.middle_name || (mhv_icn.present? ? mvi&.profile&.given_names.to_a[1..-1]&.join(' ').presence : nil)
  end

  def last_name
    identity.last_name || (mhv_icn.present? ? mvi&.profile&.family_name : nil)
  end

  def gender
    identity.gender || (mhv_icn.present? ? mvi&.profile&.gender : nil)
  end

  def birth_date
    identity.birth_date || (mhv_icn.present? ? mvi&.profile&.birth_date : nil)
  end

  def zip
    identity.zip || (mhv_icn.present? ? mvi&.profile&.address&.postal_code : nil)
  end

  def ssn
    identity.ssn || (mhv_icn.present? ? mvi&.profile&.ssn : nil)
  end

  def mhv_correlation_id
    # FIXME-IDENTITY: doing .try for now since this could return no method error until persisted properly
    identity.try(:mhv_correlation_id) || mvi.mhv_correlation_id
  end

  def loa
    identity&.loa || {}
  end

  delegate :multifactor, to: :identity, allow_nil: true
  delegate :authn_context, to: :identity, allow_nil: true
  delegate :mhv_icn, to: :identity, allow_nil: true

  # mvi attributes
  delegate :birls_id, to: :mvi
  delegate :edipi, to: :mvi
  delegate :icn, to: :mvi
  delegate :participant_id, to: :mvi
  delegate :veteran?, to: :veteran_status

  def va_profile
    mvi.profile
  end

  def va_profile_status
    mvi.status
  end

  # LOA1 no longer just means ID.me LOA1.
  # It could also be DSLogon or MHV NON PREMIUM users who have not yet done ID.me FICAM LOA3.
  # See also lib/saml/user_attributes/dslogon.rb
  # See also lib/saml/user_attributes/mhv
  def loa1?
    loa[:current] == LOA::ONE
  end

  def loa2?
    loa[:current] == LOA::TWO
  end

  # LOA3 no longer just means ID.me FICAM LOA3.
  # It could also be DSLogon or MHV Premium users.
  # It could also be DSLogon or MHV NON PREMIUM users who have done ID.me FICAM LOA3.
  # Additionally, LOA3 does not automatically mean user has opted to have MFA.
  # See also lib/saml/user_attributes/dslogon.rb
  # See also lib/saml/user_attributes/mhv
  def loa3?
    loa[:current] == LOA::THREE
  end

  def ssn_mismatch?
    return false unless loa3? && identity&.ssn && va_profile&.ssn
    identity.ssn != va_profile.ssn
  end

  def can_access_user_profile?
    loa1? || loa2? || loa3?
  end

  # User's profile contains a list of VHA facility-specific identifiers.
  # Facilities in the defined range are treating facilities, indicating
  # that the user is a VA patient.
  def va_patient?
    facilities = va_profile&.vha_facility_ids
    facilities.to_a.any? do |f|
      Settings.mhv.facility_range.any? { |range| f.to_i.between?(*range) }
    end
  end

  def mhv_account_state
    mhv_account.account_state
  end

  def can_access_appeals?
    loa3? && ssn.present?
  end

  def can_save_partial_forms?
    true
  end

  def can_access_prefill_data?
    true
  end

  def can_prefill_emis?
    edipi.present? || icn.present?
  end

  def can_access_id_card?
    loa3? && edipi.present? &&
      ID_CARD_ALLOWED_STATUSES.include?(veteran_status.title38_status)
  rescue StandardError # Default to false for any veteran_status error
    false
  end

  def identity_proofed?
    loa3?
  end

  def mhv_account
    @mhv_account ||= MhvAccount.find_or_initialize_by(user_uuid: uuid)
  end

  def in_progress_forms
    InProgressForm.where(user_uuid: uuid)
  end

  # Re-caches the MVI response. Use in response to any local changes that
  # have been made.
  def recache
    mvi.cache(uuid, mvi.mvi_response)
  end

  %w[veteran_status military_information payment].each do |emis_method|
    define_method(emis_method) do
      emis_model = instance_variable_get(:"@#{emis_method}")
      return emis_model if emis_model.present?

      emis_model = "EMISRedis::#{emis_method.camelize}".constantize.for_user(self)
      instance_variable_set(:"@#{emis_method}", emis_model)
      emis_model
    end
  end

  def identity
    @identity ||= UserIdentity.find(uuid)
  end

  private

  def mvi
    @mvi ||= Mvi.for_user(self)
  end
end
