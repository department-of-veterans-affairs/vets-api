# frozen_string_literal: true

require 'string_helpers'
require 'va_profile/configuration'
require 'va_profile/prefill/military_information'
require 'vets/model'
require 'vets/shared_logging'

# TODO(AJD): Virtus POROs for now, will become ActiveRecord when the profile is persisted
class FormFullName
  include Vets::Model

  attribute :first, String
  attribute :middle, String
  attribute :last, String
  attribute :suffix, String
end

class FormDate
  include Vets::Model

  attribute :from, Date
  attribute :to, Date
end

class FormMilitaryInformation
  include Vets::Model

  attribute :service_episodes_by_date, VAProfile::Models::ServiceHistory, array: true
  attribute :last_service_branch, String
  attribute :hca_last_service_branch, String
  attribute :last_entry_date, String
  attribute :last_discharge_date, String
  attribute :discharge_type, String
  attribute :post_nov111998_combat, Bool, default: false
  attribute :sw_asia_combat, Bool, default: false
  attribute :tours_of_duty, Hash, array: true
  attribute :currently_active_duty, Bool, default: false
  attribute :currently_active_duty_hash, Hash
  attribute :vic_verified, Bool, default: false
  attribute :service_branches, String, array: true
  attribute :service_periods, Hash, array: true
  attribute :guard_reserve_service_history, FormDate, array: true
  attribute :latest_guard_reserve_service_period, FormDate
end

class FormAddress
  include Vets::Model

  attribute :street, String
  attribute :street2, String
  attribute :city, String
  attribute :state, String
  attribute :country, String
  attribute :postal_code, String
end

class FormIdentityInformation
  include Vets::Model

  attribute :full_name, FormFullName
  attribute :date_of_birth, Date
  attribute :gender, String
  attribute :ssn, String

  def hyphenated_ssn
    StringHelpers.hyphenated_ssn(ssn)
  end

  def ssn_last_four
    ssn.last(4)
  end
end

class FormContactInformation
  include Vets::Model

  attribute :address, FormAddress
  attribute :home_phone, String
  attribute :us_phone, String
  attribute :mobile_phone, String
  attribute :email, String
end

class FormProfile
  include Vets::Model
  include Vets::SharedLogging

  MAPPINGS = Rails.root.glob('config/form_profile_mappings/*.yml').map { |f| File.basename(f, '.*') }

  ALL_FORMS = {
    acc_rep_management: %w[21-22 21-22A],
    adapted_housing: ['26-4555'],
    coe: ['26-1880'],
    decision_review: %w[20-0995 20-0996 10182],
    dependents: %w[686C-674 686C-674-V2],
    dependents_verification: %w[21-0538],
    dispute_debt: ['DISPUTE-DEBT'],
    edu: %w[22-1990 22-1990EMEB 22-1995 22-5490 22-5490E
            22-5495 22-0993 22-0994 FEEDBACK-TOOL 22-10203 22-1990EZ
            22-10297 22-0803 22-10272 22-10278],
    evss: ['21-526EZ'],
    form_mock_ae_design_patterns: ['FORM-MOCK-AE-DESIGN-PATTERNS'],
    form_mock_prefill: ['FORM-MOCK-PREFILL'],
    form_upload: %w[
      21P-4185-UPLOAD
      21-651-UPLOAD
      21-0304-UPLOAD
      21-8960-UPLOAD
      21P-4706c-UPLOAD
      21-4140-UPLOAD
      21P-4718a-UPLOAD
      21-4193-UPLOAD
      21-0788-UPLOAD
      21-8951-2-UPLOAD
      21-674b-UPLOAD
      21-2680-UPLOAD
      21-0779-UPLOAD
      21-4192-UPLOAD
      21-509-UPLOAD
      21-8940-UPLOAD
      21P-0516-1-UPLOAD
      21P-0517-1-UPLOAD
      21P-0518-1-UPLOAD
      21P-0519C-1-UPLOAD
      21P-0519S-1-UPLOAD
      21P-530a-UPLOAD
      21P-8049-UPLOAD
      21P-535-UPLOAD
    ],
    fsr: ['5655'],
    hca: %w[1010ez 10-10EZR],
    intent_to_file: ['21-0966'],
    ivc_champva: ['10-7959C'],
    mdot: ['MDOT'],
    memorials: %w[40-1330M],
    pension_burial: %w[21P-0969 21P-530EZ 21P-527EZ 21-2680 21P-601 21P-0537],
    vre_counseling: ['28-8832'],
    vre_readiness: %w[28-1900]
  }.freeze

  FORM_ID_TO_CLASS = {
    '0873' => ::FormProfiles::VA0873,
    '10-10EZR' => ::FormProfiles::VA1010ezr,
    '10-7959C' => ::FormProfiles::VHA107959c,
    '1010EZ' => ::FormProfiles::VA1010ez,
    '10182' => ::FormProfiles::VA10182,
    '40-1330M' => ::FormProfiles::VA1330m,
    '20-0995' => ::FormProfiles::VA0995,
    '20-0996' => ::FormProfiles::VA0996,
    '21-0538' => DependentsVerification::FormProfiles::VA210538,
    '21-0966' => ::FormProfiles::VA210966,
    '21-22' => ::FormProfiles::VA2122,
    '21-22A' => ::FormProfiles::VA2122a,
    '21-526EZ' => ::FormProfiles::VA526ez,
    '21P-0537' => ::FormProfiles::VA21p0537,
    '21P-0969' => IncomeAndAssets::FormProfiles::VA21p0969,
    '21P-8416' => MedicalExpenseReports::FormProfiles::VA21p8416,
    '21P-527EZ' => Pensions::FormProfiles::VA21p527ez,
    '21P-530EZ' => Burials::FormProfiles::VA21p530ez,
    '21P-601' => ::FormProfiles::VA21p601,
    '22-0993' => ::FormProfiles::VA0993,
    '22-0994' => ::FormProfiles::VA0994,
    '22-0803' => ::FormProfiles::VA0803,
    '22-10203' => ::FormProfiles::VA10203,
    '22-10272' => ::FormProfiles::VA10272,
    '22-10297' => ::FormProfiles::VA10297,
    '22-10278' => ::FormProfiles::VA10278,
    '22-1990' => ::FormProfiles::VA1990,
    '22-1990EMEB' => ::FormProfiles::VA1990emeb,
    '22-1990EZ' => ::FormProfiles::VA1990ez,
    '22-1995' => ::FormProfiles::VA1995,
    '22-5490' => ::FormProfiles::VA5490,
    '22-5490E' => ::FormProfiles::VA5490e,
    '22-5495' => ::FormProfiles::VA5495,
    '26-1880' => ::FormProfiles::VA261880,
    '26-4555' => ::FormProfiles::VA264555,
    '28-1900' => ::FormProfiles::VA281900,
    '28-8832' => ::FormProfiles::VA288832,
    '40-10007' => ::FormProfiles::VA4010007,
    '5655' => ::FormProfiles::VA5655,
    '686C-674-V2' => ::FormProfiles::VA686c674v2,
    '686C-674' => ::FormProfiles::VA686c674,
    '21-2680' => ::FormProfiles::VA212680,
    'DISPUTE-DEBT' => ::FormProfiles::DisputeDebt,
    'FEEDBACK-TOOL' => ::FormProfiles::FeedbackTool,
    'FORM-MOCK-AE-DESIGN-PATTERNS' => ::FormProfiles::FormMockAeDesignPatterns,
    'FORM-MOCK-PREFILL' => ::FormProfiles::FormMockPrefill,
    'MDOT' => ::FormProfiles::MDOT,
    '21P-0519S-1-UPLOAD' => ::FormProfiles::FormUpload,
    '21-509-UPLOAD' => ::FormProfiles::FormUpload,
    '21P-530a-UPLOAD' => ::FormProfiles::FormUpload,
    '21-651-UPLOAD' => ::FormProfiles::FormUpload,
    '21-674b-UPLOAD' => ::FormProfiles::FormUpload,
    '21-0304-UPLOAD' => ::FormProfiles::FormUpload,
    '21-0779-UPLOAD' => ::FormProfiles::FormUpload,
    '21-0788-UPLOAD' => ::FormProfiles::FormUpload,
    '21-2680-UPLOAD' => ::FormProfiles::FormUpload,
    '21-4140-UPLOAD' => ::FormProfiles::FormUpload,
    '21P-4185-UPLOAD' => ::FormProfiles::FormUpload,
    '21-4192-UPLOAD' => ::FormProfiles::FormUpload,
    '21-4193-UPLOAD' => ::FormProfiles::FormUpload,
    '21P-4706c-UPLOAD' => ::FormProfiles::FormUpload,
    '21P-4718a-UPLOAD' => ::FormProfiles::FormUpload,
    '21P-8049-UPLOAD' => ::FormProfiles::FormUpload,
    '21-8940-UPLOAD' => ::FormProfiles::FormUpload,
    '21-8960-UPLOAD' => ::FormProfiles::FormUpload,
    '21P-535-UPLOAD' => ::FormProfiles::FormUpload,
    '21P-0516-1-UPLOAD' => ::FormProfiles::FormUpload,
    '21P-0517-1-UPLOAD' => ::FormProfiles::FormUpload,
    '21P-0518-1-UPLOAD' => ::FormProfiles::FormUpload,
    '21P-0519C-1-UPLOAD' => ::FormProfiles::FormUpload,
    '21-8951-2-UPLOAD' => ::FormProfiles::FormUpload
  }.freeze

  APT_REGEX = /\S\s+((apt|apartment|unit|ste|suite).+)/i

  attr_reader :form_id, :user

  attribute :identity_information, FormIdentityInformation
  attribute :contact_information, FormContactInformation
  attribute :military_information, FormMilitaryInformation

  def self.prefill_enabled_forms
    forms = %w[40-10007 0873]
    ALL_FORMS.each { |type, form_list| forms += form_list if Settings[type].prefill }
    forms
  end

  # lookup FormProfile subclass by form_id and initialize (or use FormProfile if lookup fails)
  def self.for(form_id:, user:)
    form_id = form_id.upcase

    if form_id == '686C-674-V2' && Flipper.enabled?(:dependents_module_enabled, user)
      return DependentsBenefits::FormProfiles::VA686c674.new(form_id:, user:)
    end

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
    form_id = form_id.downcase if %w[1010EZ 40-1330M].include?(form_id) # handle case sensitivity for specific forms
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
    form = form_id == '1010EZ' ? '1010ez' : form_id

    if FormProfile.prefill_enabled_forms.include?(form)
      mappings = self.class.mappings_for_form(form_id)

      form_data = generate_prefill(mappings)

      { form_data:, metadata: }
    else
      { metadata: }
    end
  end

  def initialize_military_information
    return {} unless user.authorize :va_profile, :access?

    military_information_data = {}
    military_information_data.merge!(initialize_va_profile_prefill_military_information)
    military_information_data[:vic_verified] = user.can_access_id_card?

    FormMilitaryInformation.new(military_information_data)
  end

  private

  def initialize_va_profile_prefill_military_information
    military_information_data = {}
    military_information = VAProfile::Prefill::MilitaryInformation.new(user)

    VAProfile::Prefill::MilitaryInformation::PREFILL_METHODS.each do |attr|
      military_information_data[attr] = military_information.public_send(attr)
    end

    military_information_data
  rescue => e
    log_exception_to_rails(e)

    {}
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

    format_for_schema_compatibility(opt)
    FormContactInformation.new(opt)
  end

  # doing this (below) instead of `@vet360_contact_info ||= Settings...` to cache nil too
  def vet360_contact_info
    return @vet360_contact_info if @vet360_contact_info_retrieved

    @vet360_contact_info_retrieved = true
    if user.icn.present? || user.vet360_id.present?
      @vet360_contact_info = VAProfileRedis::V2::ContactInformation.for_user(user)
    else
      Rails.logger.info('Vet360 Contact Info Null')
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

  # returns the veteran's phone number as an object
  def phone_object
    mobile = vet360_contact_info&.mobile_phone
    return mobile if mobile&.area_code && mobile.phone_number

    home = vet360_contact_info&.home_phone
    return home if home&.area_code && home.phone_number

    phone_struct = Struct.new(:area_code, :phone_number)

    phone_struct.new
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
      value.map { |v| clean!(v) }.compact_blank!
    else
      value
    end
  end

  def clean_hash!(hash)
    hash.deep_transform_keys! { |k| k.to_s.camelize(:lower) }
    hash.each { |k, v| hash[k] = clean!(v) }
    hash.compact_blank!
  end
end
