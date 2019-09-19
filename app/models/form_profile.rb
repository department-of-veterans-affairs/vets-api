# frozen_string_literal: true

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

  EDU_FORMS = %w[22-1990 22-1990N 22-1990E 22-1995 22-1995S 22-5490
                 22-5495 22-0993 22-0994 FEEDBACK-TOOL].freeze
  EVSS_FORMS = ['21-526EZ'].freeze
  HCA_FORMS = ['1010ez'].freeze
  PENSION_BURIAL_FORMS = %w[21P-530 21P-527EZ].freeze
  VIC_FORMS = ['VIC'].freeze

  FORM_ID_TO_CLASS = {
    '1010EZ'         => ::FormProfiles::VA1010ez,
    '21-526EZ'       => ::FormProfiles::VA526ez,
    '22-1990'        => ::FormProfiles::VA1990,
    '22-1990N'       => ::FormProfiles::VA1990n,
    '22-1990E'       => ::FormProfiles::VA1990e,
    '22-1995'        => ::FormProfiles::VA1995,
    '22-1995S'       => ::FormProfiles::VA1995s,
    '22-5490'        => ::FormProfiles::VA5490,
    '22-5495'        => ::FormProfiles::VA5495,
    '21P-530'        => ::FormProfiles::VA21p530,
    '21-686C'        => ::FormProfiles::VA21686c,
    'VIC'            => ::FormProfiles::VIC,
    '40-10007'       => ::FormProfiles::VA4010007,
    '21P-527EZ'      => ::FormProfiles::VA21p527ez,
    '22-0993'        => ::FormProfiles::VA0993,
    '22-0994'        => ::FormProfiles::VA0994,
    'FEEDBACK-TOOL'  => ::FormProfiles::FeedbackTool
  }.freeze

  APT_REGEX = /\S\s+((apt|apartment|unit|ste|suite).+)/i.freeze

  attr_accessor :form_id

  attribute :identity_information, FormIdentityInformation
  attribute :contact_information, FormContactInformation
  attribute :military_information, FormMilitaryInformation

  def self.prefill_enabled_forms
    forms = []

    forms += HCA_FORMS if Settings.hca.prefill
    forms += PENSION_BURIAL_FORMS if Settings.pension_burial.prefill
    forms += EDU_FORMS if Settings.edu.prefill
    forms += VIC_FORMS if Settings.vic.prefill
    forms << '21-686C'
    forms << '40-10007'
    forms += EVSS_FORMS if Settings.evss.prefill

    forms
  end

  def self.for(form)
    form = form.upcase
    FORM_ID_TO_CLASS.fetch(form, self).new(form)
  end

  def initialize(form)
    @form_id = form
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
  def prefill(user)
    @identity_information = initialize_identity_information(user)
    @contact_information = initialize_contact_information(user)
    @military_information = initialize_military_information(user)
    mappings = self.class.mappings_for_form(form_id)

    form = form_id == '1010EZ' ? '1010ez' : form_id
    form_data = generate_prefill(mappings) if FormProfile.prefill_enabled_forms.include?(form)

    { form_data: form_data, metadata: metadata }
  end

  private

  def initialize_military_information(user)
    return {} unless user.authorize :emis, :access?
    military_information = user.military_information
    military_information_data = {}

    military_information_data[:vic_verified] = user.can_access_id_card?

    begin
      EMISRedis::MilitaryInformation::PREFILL_METHODS.each do |attr|
        military_information_data[attr] = military_information.public_send(attr)
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

  def initialize_identity_information(user)
    FormIdentityInformation.new(
      full_name: user.full_name_normalized,
      date_of_birth: user.birth_date,
      gender: user.gender,
      ssn: user.ssn_normalized
    )
  end

  def convert_vets360_address(address)
    {
      street:  address.address_line1,
      street2:  address.address_line2,
      city:  address.city,
      state:  address.state_code || address.province,
      country: address.country_code_iso3,
      postal_code:  address.zip_plus_four || address.international_postal_code
    }.compact
  end

  def initialize_vets360_contact_info(user)
    return_val = {}
    contact_information = Vet360Redis::ContactInformation.for_user(user)
    return_val[:email] = contact_information.email&.email_address

    if contact_information.mailing_address.present?
      return_val[:address] = convert_vets360_address(contact_information.mailing_address)
    end
    phone = contact_information.home_phone&.formatted_phone
    return_val[:us_phone] = phone
    return_val[:home_phone] = phone
    return_val[:mobile_phone] = contact_information.mobile_phone&.formatted_phone

    return_val
  end

  def initialize_contact_information(user)
    opt = {}
    opt.merge!(initialize_vets360_contact_info(user)) if Settings.vet360.prefill && user.vet360_id.present?

    if opt[:address].nil? && user.va_profile&.address
      opt[:address] = {
        street: user.va_profile.address.street,
        street2: nil,
        city: user.va_profile.address.city,
        state: user.va_profile.address.state,
        country: user.va_profile.address.country,
        postal_code: user.va_profile.address.postal_code
      }
    end

    opt[:email] ||= extract_pciu_data(user, :pciu_email)
    if opt[:home_phone].nil?
      pciu_primary_phone = extract_pciu_data(user, :pciu_primary_phone)
      opt[:home_phone] = pciu_primary_phone
      opt[:us_phone] = get_us_phone(pciu_primary_phone)
    end

    format_for_schema_compatibility(opt)

    FormContactInformation.new(opt)
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

  def extract_pciu_data(user, method)
    user&.send(method)
  rescue Common::Exceptions::Forbidden, Common::Exceptions::BackendServiceException
    return ''
  end

  def get_us_phone(home_phone)
    return '' if home_phone.blank?
    return home_phone if home_phone.size == 10

    return home_phone[1..-1] if home_phone.size == 11 && home_phone[0] == '1'

    ''
  end

  def convert_mapping(hash)
    prefilled = {}

    hash.each do |k, v|
      prefilled[k.camelize(:lower)] = v.is_a?(Hash) ? convert_mapping(v) : call_methods(v)
    end

    prefilled
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
    if value.is_a?(Hash)
      clean_hash!(value)
    elsif value.is_a?(Array)
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
