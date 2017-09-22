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
end

class FormAddress
  include Virtus.model

  attribute :street
  attribute :street_2
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
end

class FormContactInformation
  include Virtus.model

  attribute :address, FormAddress
  attribute :home_phone, String
  attribute :email, String
end

class FormProfile
  include SentryLogging

  MAPPINGS = Dir[Rails.root.join('config', 'form_profile_mappings', '*.yml')].map { |f| File.basename(f, '.*') }

  FORM_ID_TO_CLASS = {
    '1010EZ'    => ::FormProfile::VA1010ez,
    '22-1990'   => ::FormProfile::VA1990,
    '22-1990N'  => ::FormProfile::VA1990n,
    '22-1995'   => ::FormProfile::VA1995,
    '22-5490'   => ::FormProfile::VA5490,
    '22-5495'   => ::FormProfile::VA5495,
    '21P-530'   => ::FormProfile::VA21p530,
    '21P-527EZ' => ::FormProfile::VA21p527ez
  }.freeze

  attr_accessor :form_id
  include Virtus.model

  attribute :identity_information, FormIdentityInformation
  attribute :contact_information, FormContactInformation
  attribute :military_information, FormMilitaryInformation

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
    file = File.join(Rails.root, 'config', 'form_profile_mappings', "#{form_id}.yml")
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
    form_data = generate_prefill(mappings)
    { form_data: form_data, metadata: metadata }
  end

  private

  def initialize_military_information(user)
    return {} unless user.can_prefill_emis?

    military_information = user.military_information
    military_information_data = {}

    begin
      EMISRedis::MilitaryInformation::PREFILL_METHODS.each do |attr|
        military_information_data[attr] = military_information.public_send(attr)
      end

      military_information_data.merge!(
        receives_va_pension: user.payment.receives_va_pension
      )
    rescue => e
      # fail silently if emis is down
      log_exception_to_sentry(e, {}, backend_service: :emis)
    end

    FormMilitaryInformation.new(military_information_data)
  end

  def initialize_identity_information(user)
    FormIdentityInformation.new(
      full_name: {
        first: user.first_name&.capitalize,
        middle: user.middle_name&.capitalize,
        last: user.last_name&.capitalize,
        suffix: user.va_profile&.suffix
      },
      date_of_birth: user.birth_date,
      gender: user.gender,
      ssn: user.ssn&.gsub(/[^\d]/, '')
    )
  end

  def initialize_contact_information(user)
    return nil if user.va_profile.nil?
    address = {
      street: user.va_profile.address.street,
      street2: nil,
      city: user.va_profile.address.city,
      state: user.va_profile.address.state,
      postal_code: user.va_profile.address.postal_code,
      country: user.va_profile.address.country
    } if user.va_profile&.address
    FormContactInformation.new(
      address: address,
      email: user&.email,
      home_phone: user&.va_profile&.home_phone&.gsub(/[^\d]/, '')
    )
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
