# frozen_string_literal: true

require 'string_helpers'
require 'sentry_logging'
require 'va_profile/configuration'
require 'hca/military_information'

# TODO(AJD): Virtus POROs for now, will become ActiveRecord when the profile is persisted
class FormFullName
  include Virtus.model

  attribute :first, String
  attribute :middle, String
  attribute :last, String
  attribute :suffix, String
end

class FormDate
  include Virtus.model

  attribute :from, Date
  attribute :to, Date
end

class FormMilitaryInformation
  include Virtus.model

  attribute :post_nov_1998_combat, Boolean
  attribute :last_service_branch, String
  attribute :hca_last_service_branch, String
  attribute :last_entry_date, String
  attribute :last_discharge_date, String
  attribute :discharge_type, String
  attribute :post_nov111998_combat, Boolean
  attribute :sw_asia_combat, Boolean
  attribute :compensable_va_service_connected, Boolean
  attribute :is_va_service_connected, Boolean
  attribute :receives_va_pension, Boolean
  attribute :tours_of_duty, Array
  attribute :currently_active_duty, Boolean
  attribute :currently_active_duty_hash, Hash
  attribute :va_compensation_type, String
  attribute :vic_verified, Boolean
  attribute :service_branches, Array[String]
  attribute :service_periods, Array
  attribute :guard_reserve_service_history, Array[FormDate]
  attribute :latest_guard_reserve_service_period, FormDate
end

class FormAddress
  include Virtus.model

  attribute :street
  attribute :street2
  attribute :city
  attribute :state
  attribute :country
  attribute :postal_code
end

class FormIdentityInformation
  include Virtus.model

  attribute :full_name, FormFullName
  attribute :date_of_birth, Date
  attribute :gender, String
  attribute :ssn

  def hyphenated_ssn
    StringHelpers.hyphenated_ssn(ssn)
  end

  def ssn_last_four
    ssn.last(4)
  end
end

class FormContactInformation
  include Virtus.model

  attribute :address, FormAddress
  attribute :home_phone, String
  attribute :us_phone, String
  attribute :mobile_phone, String
  attribute :email, String
end

class FormProfile
  include Virtus.model
  include SentryLogging

  EMIS_PREFILL_KEY = 'emis_prefill'

  MAPPINGS = Dir[Rails.root.join('config', 'form_profile_mappings', '*.yml')].map { |f| File.basename(f, '.*') }

  ALL_FORMS = {
    edu: %w[22-1990 22-1990N 22-1990E 22-1990EMEB 22-1995 22-5490 22-5490E
            22-5495 22-0993 22-0994 FEEDBACK-TOOL 22-10203 22-1990S 22-1990EZ],
    evss: ['21-526EZ'],
    hca: ['1010ez'],
    pension_burial: %w[21P-530 21P-527EZ],
    dependents: ['686C-674'],
    decision_review: %w[20-0995 20-0996 10182],
    mdot: ['MDOT'],
    fsr: ['5655'],
    vre_counseling: ['28-8832'],
    vre_readiness: ['28-1900'],
    coe: ['26-1880'],
    adapted_housing: ['26-4555']
  }.freeze

  FORM_ID_TO_CLASS = {
    '0873' => ::FormProfiles::VA0873,
    '1010EZ' => ::FormProfiles::VA1010ez,
    '10182' => ::FormProfiles::VA10182,
    '20-0995' => ::FormProfiles::VA0995,
    '20-0996' => ::FormProfiles::VA0996,
    '21-526EZ' => ::FormProfiles::VA526ez,
    '22-1990' => ::FormProfiles::VA1990,
    '22-1990N' => ::FormProfiles::VA1990n,
    '22-1990E' => ::FormProfiles::VA1990e,
    '22-1990EMEB' => ::FormProfiles::VA1990emeb,
    '22-1995' => ::FormProfiles::VA1995,
    '22-5490' => ::FormProfiles::VA5490,
    '22-5490E' => ::FormProfiles::VA5490e,
    '22-5495' => ::FormProfiles::VA5495,
    '21P-530' => ::FormProfiles::VA21p530,
    '21-686C' => ::FormProfiles::VA21686c,
    '686C-674' => ::FormProfiles::VA686c674,
    '40-10007' => ::FormProfiles::VA4010007,
    '21P-527EZ' => ::FormProfiles::VA21p527ez,
    '22-0993' => ::FormProfiles::VA0993,
    '22-0994' => ::FormProfiles::VA0994,
    'FEEDBACK-TOOL' => ::FormProfiles::FeedbackTool,
    'MDOT' => ::FormProfiles::MDOT,
    '22-10203' => ::FormProfiles::VA10203,
    '22-1990S' => ::FormProfiles::VA1990s,
    '5655' => ::FormProfiles::VA5655,
    '28-8832' => ::FormProfiles::VA288832,
    '28-1900' => ::FormProfiles::VA281900,
    '22-1990EZ' => ::FormProfiles::VA1990ez,
    '26-1880' => ::FormProfiles::VA261880,
    '26-4555' => ::FormProfiles::VA264555
  }.freeze

  APT_REGEX = /\S\s+((apt|apartment|unit|ste|suite).+)/i

  attr_reader :form_id, :user

  attribute :identity_information, FormIdentityInformation
  attribute :contact_information, FormContactInformation
  attribute :military_information, FormMilitaryInformation

  def self.prefill_enabled_forms
    forms = %w[21-686C 40-10007 0873]
    ALL_FORMS.each { |type, form_list| forms += form_list if Settings[type].prefill }
    forms
  end

  # lookup FormProfile subclass by form_id and initialize (or use FormProfile if lookup fails)
  def self.for(form_id:, user:)
    form_id = form_id.upcase
    FORM_ID_TO_CLASS.fetch(form_id, self).new(form_id:, user:)
  end

  def initialize(form_id:, user:)
    @form_id = form_id
    @user = user
  end

  def metadata
    {}
  end

  def self.mappings_for_form(form_id)
    @mappings ||= {}
    @mappings[form_id] || (@mappings[form_id] = load_form_mapping(form_id))
  end

  def self.load_form_mapping(form_id)
    form_id = form_id.downcase if form_id == '1010EZ' # our first form. lessons learned.
    file = Rails.root.join('config', 'form_profile_mappings', "#{form_id}.yml")
    raise IOError, "Form profile mapping file is missing for form id #{form_id}" unless File.exist?(file)

    YAML.load_file(file)
  end

  # Collects data the VA has on hand for a user. The data may come from many databases/services.
  # In case of collisions, preference is given in this order:
  # * The form profile cache (the record for this class)
  # * ID.me
  # * MVI
  # * TODO(AJD): MIS (military history)
  #
  def prefill
    @identity_information = initialize_identity_information
    @contact_information = initialize_contact_information
    @military_information = initialize_military_information
    mappings = self.class.mappings_for_form(form_id)

    form = form_id == '1010EZ' ? '1010ez' : form_id
    form_data = generate_prefill(mappings) if FormProfile.prefill_enabled_forms.include?(form)

    { form_data:, metadata: }
  end

  private

  def initialize_military_information_vaprofile
    military_information_data = {}
    military_information = HCA::MilitaryInformation.new(user)

    HCA::MilitaryInformation::PREFILL_METHODS.each do |attr|
      military_information_data[attr] = military_information.public_send(attr)
    end

    military_information_data
  rescue => e
    if Rails.env.production?
      log_exception_to_sentry(e, {}, prefill: :vaprofile_military)

      {}
    else
      raise e
    end
  end

  def initialize_military_information
    return {} unless user.authorize :va_profile, :access?

    military_information = user.military_information
    military_information_data = {}

    military_information_data.merge!(initialize_military_information_vaprofile) if Flipper.enabled?(
      :hca_vaprofile_military_info, user
    )

    military_information_data[:vic_verified] = user.can_access_id_card?

    begin
      EMISRedis::MilitaryInformation::PREFILL_METHODS.each do |attr|
        military_information_data[attr] = military_information.public_send(attr) if military_information_data[attr].nil?
      end
    rescue => e
      if Rails.env.production?
        # fail silently if emis is down
        log_exception_to_sentry(e, {}, external_service: :emis)
      else
        raise e
      end
    end

    FormMilitaryInformation.new(military_information_data)
  end

  def initialize_identity_information
    FormIdentityInformation.new(
      full_name: user.full_name_normalized,
      date_of_birth: user.birth_date,
      gender: user.gender,
      ssn: user.ssn_normalized
    )
  end

  def vet360_mailing_address_hash
    address = vet360_mailing_address
    {
      street: address.address_line1,
      street2: address.address_line2,
      city: address.city,
      state: address.state_code || address.province,
      country: address.country_code_iso3,
      postal_code: address.zip_plus_four || address.international_postal_code,
      zip_code: address.zip_code
    }.compact
  end

  def vets360_contact_info_hash
    return_val = {}
    return_val[:email] = vet360_contact_info&.email&.email_address

    return_val[:address] = vet360_mailing_address_hash if vet360_mailing_address.present?

    phone = vet360_contact_info&.home_phone&.formatted_phone
    return_val[:us_phone] = phone
    return_val[:home_phone] = phone
    return_val[:mobile_phone] = vet360_contact_info&.mobile_phone&.formatted_phone

    return_val
  end

  def initialize_contact_information
    opt = {}
    opt.merge!(vets360_contact_info_hash) if vet360_contact_info

    opt[:address] ||= user_address_hash

    opt[:email] ||= extract_pciu_data(:pciu_email)
    if opt[:home_phone].nil?
      opt[:home_phone] = pciu_primary_phone
      opt[:us_phone] = pciu_us_phone
    end

    format_for_schema_compatibility(opt)

    FormContactInformation.new(opt)
  end

  # doing this (below) instead of `@vet360_contact_info ||= Settings...` to cache nil too
  def vet360_contact_info
    return @vet360_contact_info if @vet360_contact_info_retrieved

    @vet360_contact_info_retrieved = true
    if VAProfile::Configuration::SETTINGS.prefill && user.vet360_id.present?
      @vet360_contact_info = VAProfileRedis::ContactInformation.for_user(user)
    end
    @vet360_contact_info
  end

  def vet360_mailing_address
    vet360_contact_info&.mailing_address
  end

  def user_address_hash
    {
      street: user.address[:street],
      street2: user.address[:street2],
      city: user.address[:city],
      state: user.address[:state],
      country: user.address[:country],
      postal_code: user.address[:postal_code]
    }
  end

  def format_for_schema_compatibility(opt)
    if opt.dig(:address, :street) && opt[:address][:street2].blank? && (apt = opt[:address][:street].match(APT_REGEX))
      opt[:address][:street2] = apt[1]
      opt[:address][:street] = opt[:address][:street].gsub(/\W?\s+#{apt[1]}/, '').strip
    end

    %i[home_phone us_phone mobile_phone].each do |phone|
      opt[phone] = opt[phone].gsub(/\D/, '') if opt[phone]
    end

    opt[:address][:postal_code] = opt[:address][:postal_code][0..4] if opt.dig(:address, :postal_code)
  end

  def extract_pciu_data(method)
    user&.send(method)
  rescue Common::Exceptions::Forbidden, Common::Exceptions::BackendServiceException, EVSS::ErrorMiddleware::EVSSError
    ''
  end

  def pciu_us_phone
    return '' if pciu_primary_phone.blank?
    return pciu_primary_phone if pciu_primary_phone.size == 10

    return pciu_primary_phone[1..] if pciu_primary_phone.size == 11 && pciu_primary_phone[0] == '1'

    ''
  end

  # returns the veteran's phone number as an object
  # preference: vet360 mobile -> vet360 home -> pciu
  def phone_object
    mobile = vet360_contact_info&.mobile_phone
    return mobile if mobile&.area_code && mobile&.phone_number

    home = vet360_contact_info&.home_phone
    return home if home&.area_code && home&.phone_number

    phone_struct = Struct.new(:area_code, :phone_number)

    return phone_struct.new(pciu_us_phone.first(3), pciu_us_phone.last(7)) if pciu_us_phone&.length == 10

    phone_struct.new
  end

  def pciu_primary_phone
    @pciu_primary_phone ||= extract_pciu_data(:pciu_primary_phone)
  end

  def convert_mapping(hash)
    prefilled = {}

    hash.each do |k, v|
      if v.is_a?(Array) && v.any?(Hash)
        prefilled[k.camelize(:lower)] = []

        v.each do |h|
          nested_prefill = {}

          h.each do |key, val|
            nested_prefill[key.camelize(:lower)] = convert_value(val)
          end

          prefilled[k.camelize(:lower)] << nested_prefill
        end
      else
        prefilled[k.camelize(:lower)] = convert_value(v)
      end
    end

    prefilled
  end

  def convert_value(val)
    val.is_a?(Hash) ? convert_mapping(val) : call_methods(val)
  end

  def generate_prefill(mappings)
    result = convert_mapping(mappings)
    clean!(result)
  end

  def call_methods(methods)
    methods.inject(self) { |a, e| a.send e }.as_json
  rescue NoMethodError
    nil
  end

  def clean!(value)
    case value
    when Hash
      clean_hash!(value)
    when Array
      value.map { |v| clean!(v) }.delete_if(&:blank?)
    else
      value
    end
  end

  def clean_hash!(hash)
    hash.deep_transform_keys! { |k| k.camelize(:lower) }
    hash.each { |k, v| hash[k] = clean!(v) }
    hash.delete_if { |_k, v| v.blank? }
  end
end
