# frozen_string_literal: true

require 'common/models/base'
require 'common/models/redis_store'
require 'evss/auth_headers'
require 'evss/common_service'
require 'mpi/service'
require 'saml/user'
require 'formatters/date_formatter'
require 'va_profile/configuration'
require 'va_profile/veteran_status/service'

class User < Common::RedisStore
  include Authorization
  extend Gem::Deprecate

  # Defined per issue #6042
  ID_CARD_ALLOWED_STATUSES = %w[V1 V3 V6].freeze

  redis_store REDIS_CONFIG[:user_b_store][:namespace]
  redis_ttl REDIS_CONFIG[:user_b_store][:each_ttl]
  redis_key :uuid

  validates :uuid, presence: true

  attribute :uuid
  attribute :last_signed_in, Common::UTCTime # vaafi attributes
  attribute :mhv_last_signed_in, Common::UTCTime # MHV audit logging
  attribute :user_account_uuid, String
  attribute :user_verification_id, Integer
  attribute :fingerprint, String
  attribute :needs_accepted_terms_of_use, Boolean
  attribute :credential_lock, Boolean
  attribute :session_handle, String

  def initial_sign_in
    user_account.created_at
  end

  def credential_lock
    return @credential_lock unless @credential_lock.nil?

    @credential_lock = user_verification&.locked
  end

  def needs_accepted_terms_of_use
    return @needs_accepted_terms_of_use unless @needs_accepted_terms_of_use.nil?

    @needs_accepted_terms_of_use = user_account&.needs_accepted_terms_of_use?
  end

  def user_verification
    @user_verification ||= UserVerification.find_by(id: user_verification_id)
  end

  def user_account
    @user_account ||= user_verification&.user_account
  end

  def user_verification_id
    @user_verification_id ||= get_user_verification&.id
  end

  def user_account_uuid
    @user_account_uuid ||= user_account&.id
  end

  # Identity attributes & methods
  delegate :authn_context, to: :identity, allow_nil: true
  delegate :email, to: :identity, allow_nil: true
  delegate :idme_uuid, to: :identity, allow_nil: true
  delegate :loa3?, to: :identity, allow_nil: true
  delegate :logingov_uuid, to: :identity, allow_nil: true
  delegate :mhv_credential_uuid, to: :identity, allow_nil: true
  delegate :mhv_icn, to: :identity, allow_nil: true
  delegate :multifactor, to: :identity, allow_nil: true
  delegate :sign_in, to: :identity, allow_nil: true, prefix: true
  delegate :verified_at, to: :identity, allow_nil: true

  # Returns a Date string in iso8601 format, eg. '{year}-{month}-{day}'
  def birth_date
    birth_date = identity.birth_date || birth_date_mpi

    Formatters::DateFormatter.format_date(birth_date)
  end

  def first_name
    identity.first_name.presence || first_name_mpi
  end

  def common_name
    [first_name, middle_name, last_name, suffix].compact.join(' ')
  end

  def edipi
    loa3? && identity.edipi.present? ? identity.edipi : edipi_mpi
  end

  def full_name_normalized
    {
      first: first_name&.capitalize,
      middle: middle_name&.capitalize,
      last: last_name&.capitalize,
      suffix: normalized_suffix
    }
  end

  def preferred_name
    preferred_name_mpi
  end

  def gender
    identity.gender.presence || gender_mpi
  end

  def icn
    identity&.icn || mpi&.icn
  end

  def loa
    identity&.loa || {}
  end

  def mhv_account_type
    identity.mhv_account_type || MHVAccountTypeService.new(self).mhv_account_type
  end

  def mhv_correlation_id
    return unless can_create_mhv_account?
    return mhv_user_account.id if mhv_user_account.present?

    mpi_mhv_correlation_id if active_mhv_ids&.one?
  end

  def mhv_user_account(from_cache_only: true)
    @mhv_user_account ||= MHV::UserAccount::Creator.new(user_verification:, from_cache_only:).perform
  rescue => e
    log_mhv_user_account_error(e.message)
    nil
  end

  def middle_name
    identity.middle_name.presence || middle_name_mpi
  end

  def last_name
    identity.last_name.presence || last_name_mpi
  end

  def sec_id
    identity&.sec_id || mpi_profile&.sec_id
  end

  def ssn
    identity&.ssn || ssn_mpi
  end

  def ssn_normalized
    ssn&.gsub(/[^\d]/, '')
  end

  # MPI attributes & methods
  delegate :birls_id, to: :mpi
  delegate :cerner_id, to: :mpi
  delegate :cerner_facility_ids, to: :mpi
  delegate :edipis, to: :mpi, prefix: true
  delegate :error, to: :mpi, prefix: true
  delegate :icn, to: :mpi, prefix: true
  delegate :icn_with_aaid, to: :mpi
  delegate :id_theft_flag, to: :mpi
  delegate :mhv_correlation_id, to: :mpi, prefix: true
  delegate :mhv_ien, to: :mpi
  delegate :mhv_iens, to: :mpi, prefix: true
  delegate :npi_id, to: :mpi
  delegate :participant_id, to: :mpi
  delegate :participant_ids, to: :mpi, prefix: true
  delegate :person_types, to: :mpi
  delegate :search_token, to: :mpi
  delegate :status, to: :mpi, prefix: true
  delegate :vet360_id, to: :mpi

  def active_mhv_ids
    mpi_profile&.active_mhv_ids&.uniq
  end

  def address
    address = mpi_profile&.address
    {
      street: address&.street,
      street2: address&.street2,
      city: address&.city,
      state: address&.state,
      country: address&.country,
      postal_code: address&.postal_code
    }
  end

  def deceased_date
    Formatters::DateFormatter.format_date(mpi_profile&.deceased_date)
  end

  def birth_date_mpi
    mpi_profile&.birth_date
  end

  def edipi_mpi
    mpi_profile&.edipi
  end

  def first_name_mpi
    given_names&.first
  end

  def preferred_name_mpi
    mpi_profile&.preferred_names&.first
  end

  def middle_name_mpi
    mpi&.profile&.given_names.to_a[1..]&.join(' ').presence
  end

  def gender_mpi
    mpi_profile&.gender
  end

  def given_names
    mpi_profile&.given_names
  end

  def home_phone
    mpi_profile&.home_phone
  end

  def last_name_mpi
    mpi_profile&.family_name
  end

  def mhv_account_state
    return 'DEACTIVATED' if (mhv_ids.to_a - active_mhv_ids.to_a).any?
    return 'MULTIPLE' if active_mhv_ids.to_a.size > 1
    return 'NONE' if mhv_correlation_id.blank?

    'OK'
  end

  def mhv_ids
    mpi_profile&.mhv_ids
  end

  def normalized_suffix
    mpi_profile&.normalized_suffix
  end

  def postal_code
    mpi&.profile&.address&.postal_code
  end

  def ssn_mpi
    mpi_profile&.ssn
  end

  def suffix
    mpi_profile&.suffix
  end

  def mpi_profile?
    mpi_profile != nil
  end

  def vha_facility_ids
    mpi_profile&.vha_facility_ids || []
  end

  def vha_facility_hash
    mpi_profile&.vha_facility_hash || {}
  end

  def mpi_gcids
    mpi_profile&.full_mvi_ids || []
  end

  # MPI setter methods

  def set_mhv_ids(mhv_id)
    mpi_profile.mhv_ids = [mhv_id] + mhv_ids
    mpi_profile.active_mhv_ids = [mhv_id] + active_mhv_ids
    recache
  end

  # Other MPI

  def validate_mpi_profile
    return unless mpi_profile?

    raise MPI::Errors::AccountLockedError, 'Death Flag Detected' if mpi_profile.deceased_date
    raise MPI::Errors::AccountLockedError, 'Theft Flag Detected' if mpi_profile.id_theft_flag
  end

  def invalidate_mpi_cache
    return unless loa3? && mpi.mpi_response_is_cached? && mpi.mvi_response

    mpi.destroy
    @mpi = nil
  end

  # VA Profile attributes
  delegate :military_person?, to: :veteran_status
  delegate :veteran?, to: :veteran_status

  def ssn_mismatch?
    return false unless loa3? && identity&.ssn && ssn_mpi

    identity.ssn != ssn_mpi
  end

  def can_access_user_profile?
    loa[:current].present?
  end

  # True if the user has 1 or more treatment facilities, false otherwise
  def va_patient?
    va_treatment_facility_ids.any?
  end

  # User's profile contains a list of VHA facility-specific identifiers.
  # Facilities in the defined range are treating facilities
  def va_treatment_facility_ids
    facilities = vha_facility_ids
    facilities.select do |f|
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

  def in_progress_forms
    InProgressForm.for_user(self)
  end

  # Re-caches the MPI response. Use in response to any local changes that
  # have been made.
  def recache
    mpi.cache(uuid, mpi.mvi_response)
  end

  # destroy both UserIdentity and self
  def destroy
    identity&.destroy
    super
  end

  def veteran_status
    @veteran_status ||= VAProfileRedis::VeteranStatus.for_user(self)
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

  def onboarding
    @onboarding ||= VeteranOnboarding.for_user(self)
  end

  # VeteranOnboarding attributes & methods
  delegate :show_onboarding_flow_on_login, to: :onboarding, allow_nil: true

  def vet360_contact_info
    return nil unless vet360_id.present? || icn.present?

    @vet360_contact_info ||= VAProfileRedis::V2::ContactInformation.for_user(self)
  end

  def va_profile_email
    vet360_contact_info&.email&.email_address
  end

  def vaprofile_contact_info
    return nil unless VAProfile::Configuration::SETTINGS.contact_information.enabled && icn.present?

    @vaprofile_contact_info ||= VAProfileRedis::V2::ContactInformation.for_user(self)
  end

  def va_profile_v2_email
    vaprofile_contact_info&.email&.email_address
  end

  def all_emails
    the_va_profile_email =
      begin
        va_profile_email
      rescue
        nil
      end

    [the_va_profile_email, email]
      .compact_blank
      .map(&:downcase)
      .uniq
  end

  def can_access_vet360?
    loa3? && icn.present? && vet360_id.present?
  rescue # Default to false for any error
    false
  end

  # A user can have served in the military without being a veteran.  For example,
  # someone can be ex-military by having a discharge status higher than
  # 'Other Than Honorable'.
  #
  # @return [Boolean]
  #
  def served_in_military?
    (edipi.present? && veteran?) || military_person?
  end

  def flipper_id
    email&.downcase || user_account_uuid
  end

  def relationships
    @relationships ||= get_relationships_array
  end

  def create_mhv_account_async
    return unless can_create_mhv_account?

    MHV::AccountCreatorJob.perform_async(user_verification_id)
  end

  def provision_cerner_async(source: nil)
    return unless cerner_eligible?

    Identity::CernerProvisionerJob.perform_async(icn, source)
  end

  def cerner_eligible?
    loa3? && cerner_id.present?
  end

  def can_create_mhv_account?
    loa3? && !needs_accepted_terms_of_use
  end

  private

  def mpi_profile
    return nil unless identity && mpi

    mpi.profile
  end

  def mpi
    @mpi ||= MPIData.for_user(identity)
  end

  # Get user_verification based on login method
  # Default is idme, if login method and login uuid are not available,
  # fall back to idme
  def get_user_verification
    case identity_sign_in&.dig(:service_name)
    when SAML::User::MHV_ORIGINAL_CSID
      return UserVerification.find_by(mhv_uuid: mhv_credential_uuid) if mhv_credential_uuid
    when SAML::User::DSLOGON_CSID
      return UserVerification.find_by(dslogon_uuid: identity.edipi) if identity.edipi
    when SAML::User::LOGINGOV_CSID
      return UserVerification.find_by(logingov_uuid:) if logingov_uuid
    end
    return nil unless idme_uuid

    UserVerification.find_by(idme_uuid:) || UserVerification.find_by(backing_idme_uuid: idme_uuid)
  end

  def get_relationships_array
    return unless loa3?

    mpi_profile_relationships || bgs_relationships
  end

  def mpi_profile_relationships
    return unless mpi_profile && mpi_profile.relationships.presence

    mpi_profile.relationships.map { |relationship| UserRelationship.from_mpi_relationship(relationship) }
  end

  def bgs_relationships
    bgs_dependents = BGS::DependentService.new(self).get_dependents
    return unless bgs_dependents.presence && bgs_dependents[:persons]

    bgs_dependents[:persons].map { |dependent| UserRelationship.from_bgs_dependent(dependent) }
  end

  def log_mhv_user_account_error(error_message)
    Rails.logger.info('[User] mhv_user_account error', error_message:, icn:)
  end
end
