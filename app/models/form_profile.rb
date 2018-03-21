# frozen_string_literal: true

# TODO(AJD): Virtus POROs for now, will become ActiveRecord when the profile is persisted
class FormFullName
  include Virtus.model

  attribute :first, String
  attribute :middle, String
  attribute :last, String
  attribute :suffix, String
end

class FormMilitaryInformation
  include Virtus.model

  attribute :post_nov_1998_combat, Boolean
  attribute :last_service_branch, String
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
end

class FormAddress
  include Virtus.model

  attribute :street
  attribute :street_2
  attribute :city
  attribute :state
  attribute :country
  attribute :postal_code
  attribute :zipcode
end

class FormIdentityInformation
  include Virtus.model

  attribute :full_name, FormFullName
  attribute :date_of_birth, Date
  attribute :gender, String
  attribute :ssn
end

class FormContactInformation
  include Virtus.model

  attribute :address, FormAddress
  attribute :home_phone, String
  attribute :us_phone, String
  attribute :email, String
end

class FormProfile
  include SentryLogging

  EMIS_PREFILL_KEY = 'emis_prefill'

  MAPPINGS = Dir[Rails.root.join('config', 'form_profile_mappings', '*.yml')].map { |f| File.basename(f, '.*') }

  EDU_FORMS = ['22-1990', '22-1990N', '22-1990E', '22-1995', '22-5490', '22-5495'].freeze
  HCA_FORMS = ['1010ez'].freeze
  PENSION_BURIAL_FORMS = ['21P-530', '21P-527EZ'].freeze
  VIC_FORMS = ['VIC'].freeze

  FORM_ID_TO_CLASS = {
    '1010EZ'    => ::FormProfiles::VA1010ez,
    '22-1990'   => ::FormProfiles::VA1990,
    '22-1990N'  => ::FormProfiles::VA1990n,
    '22-1990E'  => ::FormProfiles::VA1990e,
    '22-1995'   => ::FormProfiles::VA1995,
    '22-5490'   => ::FormProfiles::VA5490,
    '22-5495'   => ::FormProfiles::VA5495,
    '21P-530'   => ::FormProfiles::VA21p530,
    'VIC'       => ::FormProfiles::VIC,
    '21P-527EZ' => ::FormProfiles::VA21p527ez
  }.freeze

  attr_accessor :form_id
  include Virtus.model

  attribute :identity_information, FormIdentityInformation
  attribute :contact_information, FormContactInformation
  attribute :military_information, FormMilitaryInformation

  def self.prefill_enabled_forms
    forms = []

    forms += HCA_FORMS if Settings.hca.prefill
    forms += PENSION_BURIAL_FORMS if Settings.pension_burial.prefill
    forms += EDU_FORMS if Settings.edu.prefill
    forms += VIC_FORMS if Settings.vic.prefill

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
    return {} unless user.can_prefill_emis?

    military_information = user.military_information
    military_information_data = {}

    military_information_data[:vic_verified] = user.authorize :id_card, :access?

    begin
      EMISRedis::MilitaryInformation::PREFILL_METHODS.each do |attr|
        military_information_data[attr] = military_information.public_send(attr)
      end
    rescue => e
      if Rails.env.production?
        # fail silently if emis is down
        log_exception_to_sentry(e, {}, backend_service: :emis)
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

  def initialize_contact_information(user)
    return nil if user.va_profile.nil?

    if user.va_profile&.address
      address = {
        street: user.va_profile.address.street,
        street2: nil,
        city: user.va_profile.address.city,
        state: user.va_profile.address.state,
        country: user.va_profile.address.country
      }
    end

    address.merge!(derive_postal_code(user)) if address.present?

    home_phone = user&.va_profile&.home_phone&.gsub(/[^\d]/, '')

    FormContactInformation.new(
      address: address,
      email: user&.email,
      us_phone: get_us_phone(home_phone),
      home_phone: home_phone
    )
  end

  # For 10-10ez forms, this function is overridden to provide a different
  # key for postal_code is used depending on the country. The default behaviour
  # here is used for other form types
  def derive_postal_code(user)
    { postal_code: user.va_profile.address.postal_code }
  end

  def get_us_phone(home_phone)
    return '' if home_phone.blank?
    return home_phone if home_phone.size == 10

    return home_phone[1..-1] if home_phone.size == 11 && home_phone[0] == '1'

    ''
  end

  def generate_prefill(mappings)
    result = mappings.map do |k, v|
      method_chain = v.map(&:to_sym)
      { k.camelize(:lower) => call_methods(method_chain) }
    end.reduce({}, :merge)

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
    hash.each { |k, v| hash[k] = clean!(v) }
    hash.delete_if { |_k, v| v.blank? }
  end
end
