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

  redis_store REDIS_CONFIG['user_store']['namespace']
  redis_ttl REDIS_CONFIG['user_store']['each_ttl']
  redis_key :uuid

  # SAML Attributes
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
  attribute :multifactor   # used by F/E to decision on whether or not to prompt user to add MFA
  attribute :authn_context # used by F/E to handle various identity related complexities pending refactor
  attribute :mhv_icn # only needed by B/E not serialized in user_serializer
  attribute :mhv_uuid # this is the cannonical version of MHV Correlation ID, provided by MHV sign-in users

  # Non SAML Attributes
  attribute :last_signed_in, Common::UTCTime # vaafi attributes
  attribute :mhv_last_signed_in, Common::UTCTime # MHV audit logging

  # Validations
  validates :uuid, presence: true
  validates :email, presence: true
  validates :loa, presence: true

  # Getter Overrides - IMPORTANT, the source of truth should be MVI when available.
  def first_name
    loa3? ? va_profile.given_names.first || super : super
  end

  def middle_name
    loa3? ? va_profile.given_names.second || super : super
  end

  def last_name
    loa3? ? va_profile.family_name || super : super
  end

  def gender
    loa3? ? va_profile.gender || super : super
  end

  def birth_date
    loa3? ? va_profile.birth_date || super : super
  end

  def zip
    loa3? ? va_profile.address.postal_code || super : super
  end

  def ssn
    if loa3? && va_profile.ssn == super
      va_profile.ssn
    else
      # Flag for potential fraud? If so, this should probably happen at initialization
      # Should other heuristics be considered such as birth_date?
      nil
    end
  end

  def mhv_correlation_id
    loa3? ? mhv_uuid || mvi.mhv_correlation_id : nil
  end


  # LOA1 is not just ID.me LOA1, DSLogon or MHV "Non-Premium" users who have not done "FICAM LOA3".
  def loa1?
    loa[:current] == LOA::ONE
  end

  # FIXME This method should be removed.
  def loa2?
    loa[:current] == LOA::TWO
  end

  # LOA3 could be ID.me FICAM LOA3, DSLogon or MHV "Premium" users, or "Non-Premium with FICAM LOA3".
  def loa3?
    loa[:current] == LOA::THREE
  end

  def can_access_user_profile?
    loa1? || loa2? || loa3?
  end

  # Must be LOA3 and a va patient
  def mhv_account_eligible?
    (MhvAccount::ALL_STATES - [:ineligible]).map(&:to_s).include?(mhv_account_state)
  end

  def mhv_account_state
    return nil unless loa3?
    mhv_account.account_state
  end

  def can_access_evss?
    edipi.present? && ssn.present? && participant_id.present?
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
    beta_enabled?(uuid, FormProfile::EMIS_PREFILL_KEY)
  end

  def can_access_id_card?
    beta_enabled?(uuid, 'veteran_id_card') && loa3? && edipi.present? && veteran?
  rescue # Default to false for any veteran_status error
    false
  end

  # FIXME - why is this really necessary? Shouldn't the LOA3 have everything the LOA1 has? Why can't we just
  # expire the old and only use the new? (except maybe for multifactor) which would be cleaner / safer?
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

  %w(veteran_status military_information payment).each do |emis_method|
    define_method(emis_method) do
      emis_model = instance_variable_get(:"@#{emis_method}")
      return emis_model if emis_model.present?

      emis_model = "EMISRedis::#{emis_method.camelize}".constantize.for_user(self)
      instance_variable_set(:"@#{emis_method}", emis_model)
      emis_model
    end
  end

  private

  def mvi
    @mvi ||= Mvi.for_user(self)
  end
end
