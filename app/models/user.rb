# frozen_string_literal: true

require 'beta_switch'
require 'common/models/base'
require 'common/models/redis_store'
require 'evss/auth_headers'
require 'evss/common_service'
require 'evss/pciu/service'
require 'mpi/messages/find_profile_message'
require 'mpi/service'
require 'saml/user'
require 'formatters/date_formatter'
require 'va_profile/configuration'

class User < Common::RedisStore
  include BetaSwitch
  include Authorization
  extend Gem::Deprecate

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
  attribute :account_uuid, String
  attribute :account_id, Integer

  delegate :email, to: :identity, allow_nil: true
  delegate :loa3?, to: :identity, allow_nil: true

  # Retrieve a user's Account record
  #
  # @return [Account] an instance of the Account object
  #
  def account
    @account ||= Account.create_by!(self)
  end

  def account_uuid
    @account_uuid ||= account&.uuid
  end

  def account_id
    @account_id ||= account&.id
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

  # Identity getter methods

  def birls_id
    identity&.birls_id || mpi_birls_id
  end

  # Returns a Date string in iso8601 format, eg. '{year}-{month}-{day}'
  def birth_date
    birth_date = identity.birth_date || birth_date_mpi

    Rails.logger.info "[User] Cannot find birth date for User with uuid: #{uuid}" if birth_date.nil?

    Formatters::DateFormatter.format_date(birth_date)
  end

  def first_name
    identity.first_name.presence || first_name_mpi
  end

  def full_name_normalized
    {
      first: first_name&.capitalize,
      middle: middle_name&.capitalize,
      last: last_name&.capitalize,
      suffix: normalized_suffix
    }
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
    identity.mhv_correlation_id || mpi.mhv_correlation_id
  end

  def middle_name
    identity.middle_name.presence || middle_name_mpi
  end

  def last_name
    identity.last_name.presence || last_name_mpi
  end

  def participant_id
    identity&.participant_id || mpi&.participant_id
  end

  def sec_id
    identity&.sec_id || mpi_profile&.sec_id
  end

  def ssn
    identity.ssn || ssn_mpi
  end

  def ssn_normalized
    ssn&.gsub(/[^\d]/, '')
  end

  def zip
    identity.zip || mpi&.profile&.address&.postal_code
  end

  # MPI getter methods

  def active_mhv_ids
    mpi_profile&.active_mhv_ids
  end

  def address
    address = mpi_profile&.address
    {
      street: address&.street,
      city: address&.city,
      state: address&.state,
      country: address&.country,
      zip: address&.postal_code
    }
  end

  def birth_date_mpi
    return nil unless mpi_profile

    if mpi_profile.birth_date.nil?
      Rails.logger.info "[User] Cannot find birth date from MPI profile for User with uuid: #{uuid}"
      return nil
    end

    mpi_profile.birth_date
  end

  def edipi_mpi
    mpi_profile&.edipi
  end

  def first_name_mpi
    given_names&.first
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

  def historical_icns
    @mpi_historical_icn ||= MPIData.historical_icn_for_user(self)
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

  def person_types
    identity_person_types.presence || mpi_person_types
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

  # MPI setter methods

  def mpi_add_person
    add_person_identity = identity
    add_person_identity.edipi = edipi
    add_person_identity.ssn = ssn
    add_person_identity.icn_with_aaid = icn_with_aaid
    add_person_identity.search_token = search_token
    mpi.user_identity = add_person_identity
    mpi.add_person
  end

  def set_mhv_ids(mhv_id)
    mpi_profile.mhv_ids = [mhv_id] + mhv_ids
    mpi_profile.active_mhv_ids = [mhv_id] + active_mhv_ids
    recache
  end

  # Other MPI

  def invalidate_mpi_cache
    mpi_cache = mpi
    mpi_cache.mvi_response
    mpi_cache.destroy
  end

  # identity attributes
  delegate :multifactor, to: :identity, allow_nil: true
  delegate :authn_context, to: :identity, allow_nil: true
  delegate :mhv_icn, to: :identity, allow_nil: true
  delegate :idme_uuid, to: :identity, allow_nil: true
  delegate :logingov_uuid, to: :identity, allow_nil: true
  delegate :verified_at, to: :identity, allow_nil: true
  delegate :common_name, to: :identity, allow_nil: true
  delegate :person_types, to: :identity, allow_nil: true, prefix: true

  # mpi attributes
  delegate :birls_id, to: :mpi, prefix: true
  delegate :cerner_id, to: :mpi
  delegate :cerner_facility_ids, to: :mpi
  delegate :icn, to: :mpi, prefix: true
  delegate :icn_with_aaid, to: :mpi
  delegate :vet360_id, to: :mpi
  delegate :search_token, to: :mpi
  delegate :person_types, to: :mpi, prefix: true
  delegate :id_theft_flag, to: :mpi
  delegate :status, to: :mpi, prefix: true
  delegate :error, to: :mpi, prefix: true

  # emis attributes
  delegate :military_person?, to: :veteran_status
  delegate :veteran?, to: :veteran_status

  def edipi
    loa3? && identity.edipi.present? ? identity.edipi : edipi_mpi
  end

  def ssn_mismatch?
    return false unless loa3? && identity&.ssn && ssn_mpi

    identity.ssn != ssn_mpi
  end

  def can_access_user_profile?
    loa[:current].present?
  end

  # True if the user has 1 or more treatment facilities, false otherwise
  def va_patient?
    va_treatment_facility_ids.length.positive?
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

  def vha_facility_ids
    mpi_profile&.vha_facility_ids || []
  end

  def vha_facility_hash
    mpi_profile&.vha_facility_hash || {}
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
    return nil unless VAProfile::Configuration::SETTINGS.contact_information.enabled && vet360_id.present?

    @vet360_contact_info ||= VAProfileRedis::ContactInformation.for_user(self)
  end

  def va_profile_email
    vet360_contact_info&.email&.email_address
  end

  def all_emails
    the_va_profile_email =
      begin
        va_profile_email
      rescue
        nil
      end

    [the_va_profile_email, email]
      .reject(&:blank?)
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
    edipi.present? && veteran? || military_person?
  end

  def power_of_attorney
    EVSS::CommonService.get_current_info[:poa]
  end

  def flipper_id
    email&.downcase || account_uuid
  end

  def relationships
    @relationships ||= get_relationships_array
  end

  private

  def mpi
    @mpi ||= MPIData.for_user(identity)
  end

  def mpi_profile
    return nil unless identity && mpi

    mpi.profile
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

  def pciu
    @pciu ||= EVSS::PCIU::Service.new self if loa3? && edipi.present?
  end
end
