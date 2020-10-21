# frozen_string_literal: true

require 'beta_switch'
require 'common/models/base'
require 'common/models/redis_store'
require 'evss/auth_headers'
require 'evss/common_service'
require 'evss/pciu/service'
require 'mvi/messages/find_profile_message'
require 'mvi/service'
require 'saml/user'

class User < Common::RedisStore
  include BetaSwitch
  include Authorization

  UNALLOCATED_SSN_PREFIX = '796' # most test accounts use this

  # Defined per issue #6042
  ID_CARD_ALLOWED_STATUSES = %w[V1 V3 V6].freeze

  redis_store REDIS_CONFIG[:user_b_store][:namespace]
  redis_ttl REDIS_CONFIG[:user_b_store][:each_ttl]
  redis_key :uuid

  validates :uuid, presence: true

  with_options if: :loa3? do
    validates :ssn, format: /\A\d{9}\z/, allow_blank: true
    validates :gender, format: /\A(M|F)\z/, allow_blank: true
  end

  attribute :uuid
  attribute :last_signed_in, Common::UTCTime # vaafi attributes
  attribute :mhv_last_signed_in, Common::UTCTime # MHV audit logging

  delegate :email, to: :identity, allow_nil: true

  # This delegated method is called with #account_uuid
  delegate :uuid, to: :account, prefix: true, allow_nil: true

  # Retrieve a user's Account record.  Checks the cache before executing
  # any database calls.
  #
  # @return [Account] an instance of the Account object
  #
  def account
    Account.cache_or_create_by!(self)
  end

  def pciu_email
    pciu&.get_email_address&.email
  end

  def pciu_primary_phone
    pciu&.get_primary_phone&.to_s
  end

  def pciu_alternate_phone
    pciu&.get_alternate_phone&.to_s
  end

  def first_name
    identity.first_name || (mhv_icn.present? ? mvi&.profile&.given_names&.first : nil)
  end

  def full_name_normalized
    {
      first: first_name&.capitalize,
      middle: middle_name&.capitalize,
      last: last_name&.capitalize,
      suffix: va_profile&.normalized_suffix
    }
  end

  def ssn_normalized
    ssn&.gsub(/[^\d]/, '')
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
    identity.mhv_correlation_id || mvi.mhv_correlation_id
  end

  def mhv_account_type
    identity.mhv_account_type || MHVAccountTypeService.new(self).mhv_account_type
  end

  def mhv_account_state
    return 'DEACTIVATED' if (va_profile.mhv_ids.to_a - va_profile.active_mhv_ids.to_a).any?
    return 'MULTIPLE' if va_profile.active_mhv_ids.to_a.size > 1
    return 'NONE' if mhv_correlation_id.blank?

    'OK'
  end

  def loa
    identity&.loa || {}
  end

  delegate :multifactor, to: :identity, allow_nil: true
  delegate :authn_context, to: :identity, allow_nil: true
  delegate :mhv_icn, to: :identity, allow_nil: true
  delegate :idme_uuid, to: :identity, allow_nil: true
  delegate :dslogon_edipi, to: :identity, allow_nil: true
  delegate :common_name, to: :identity, allow_nil: true

  # mvi attributes
  delegate :birls_id, to: :mvi
  delegate :icn, to: :mvi
  delegate :icn_with_aaid, to: :mvi
  delegate :participant_id, to: :mvi
  delegate :vet360_id, to: :mvi
  delegate :search_token, to: :mvi

  # emis attributes
  delegate :military_person?, to: :veteran_status
  delegate :veteran?, to: :veteran_status

  def edipi
    loa3? && dslogon_edipi.present? ? dslogon_edipi : mvi&.edipi
  end

  def sec_id
    identity.sec_id || va_profile&.sec_id
  end

  def va_profile
    mvi.profile
  end

  def va_profile_status
    mvi.status
  end

  def va_profile_error
    mvi.error
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
    loa[:current].try(:to_i) == LOA::THREE
  end

  def ssn_mismatch?
    return false unless loa3? && identity&.ssn && va_profile&.ssn

    identity.ssn != va_profile.ssn
  end

  def can_access_user_profile?
    loa1? || loa2? || loa3?
  end

  # True if the user has 1 or more treatment facilities, false otherwise
  def va_patient?
    va_treatment_facility_ids.length.positive?
  end

  # User's profile contains a list of VHA facility-specific identifiers.
  # Facilities in the defined range are treating facilities
  def va_treatment_facility_ids
    facilities = va_profile&.vha_facility_ids
    facilities.to_a.select do |f|
      Settings.mhv.facility_range.any? { |range| f.to_i.between?(*range) } ||
        Settings.mhv.facility_specific.include?(f)
    end
  end

  def can_access_id_card?
    loa3? && edipi.present? &&
      ID_CARD_ALLOWED_STATUSES.include?(veteran_status.title38_status)
  rescue # Default to false for any veteran_status error
    false
  end

  def identity_proofed?
    loa3?
  end

  def mhv_account
    @mhv_account ||= MHVAccount.find_or_initialize_by(user_uuid: uuid, mhv_correlation_id: mhv_correlation_id)
                               .tap { |m| m.user = self } # MHV account should not re-initialize use
  end

  def in_progress_forms
    InProgressForm.where(user_uuid: uuid)
  end

  # Re-caches the MVI response. Use in response to any local changes that
  # have been made.
  def recache
    mvi.cache(uuid, mvi.mvi_response)
  end

  # destroy both UserIdentity and self
  def destroy
    identity&.destroy
    super
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

  %w[profile grants].each do |okta_model_name|
    okta_method = "okta_#{okta_model_name}"
    define_method(okta_method) do
      okta_instance = instance_variable_get(:"@#{okta_method}")
      return okta_instance if okta_instance.present?

      okta_model = "OktaRedis::#{okta_model_name.camelize}".constantize.with_user(self)
      instance_variable_set(:"@#{okta_method}", okta_model)
      okta_model
    end
  end

  def identity
    @identity ||= UserIdentity.find(uuid)
  end

  def vet360_contact_info
    return nil unless Settings.vet360.contact_information.enabled && vet360_id.present?

    @vet360_contact_info ||= Vet360Redis::ContactInformation.for_user(self)
  end

  def all_emails
    vet360_email =
      begin
        vet360_contact_info&.email&.email_address
      rescue
        nil
      end

    [vet360_email, email]
      .reject(&:blank?)
      .map(&:downcase)
      .uniq
  end

  def can_access_vet360?
    loa3? && icn.present? && vet360_id.present?
  rescue # Default to false for any error
    false
  end

  def can_mvi_proxy_add?
    personal_info? && edipi.present? && icn_with_aaid.present? && search_token.present?
  rescue # Default to false for any error
    false
  end

  def personal_info?
    first_name.present? && last_name.present? && ssn.present? && birth_date.present?
  end

  def mvi
    @mvi ||= MPIData.for_user(self)
  end

  # A user can have served in the military without being a veteran.  For example,
  # someone can be ex-military by having a discharge status higher than
  # 'Other Than Honorable'.
  #
  # @return [Boolean]
  #
  def served_in_military?
    edipi.present? && veteran? || military_person?
  end

  def power_of_attorney
    EVSS::CommonService.get_current_info[:poa]
  end

  def flipper_id
    email || account_uuid
  end

  private

  def pciu
    @pciu ||= EVSS::PCIU::Service.new self if loa3? && edipi.present?
  end
end
