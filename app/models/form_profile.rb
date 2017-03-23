# frozen_string_literal: true
# TODO(AJD): Virtus POROs for now, will become ActiveRecord when the profile is persisted
class FormFullName
  include Virtus.model

  attribute :first, String
  attribute :middle, String
  attribute :last, String
  attribute :suffix, String
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
end

class FormContactInformation
  include Virtus.model

  attribute :address, FormAddress
  attribute :home_phone, String
end

class FormProfile
  include Virtus.model

  attribute :identity_information, FormIdentityInformation
  attribute :contact_information, FormContactInformation

  def self.mappings_for_form(form_id)
    @mappings ||= {}
    @mappings[form_id] || (@mappings[form_id] = load_form_mapping(form_id))
  end

  def self.load_form_mapping(form_id)
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
  def prefill_form(form_id, user)
    @identity_information = initialize_identity_information(user)
    @contact_information = initialize_contact_information(user)
    mappings = self.class.mappings_for_form(form_id)
    generate_prefill(mappings)
  end

  private

  def initialize_identity_information(user)
    FormIdentityInformation.new(
      full_name: {
        first: user.first_name&.capitalize,
        middle: user.middle_name&.capitalize,
        last: user.last_name&.capitalize,
        suffix: user.va_profile.suffix
      },
      date_of_birth: user.birth_date,
      gender: user.gender
    )
  end

  def initialize_contact_information(user)
    FormContactInformation.new(
      address: {
        street: user.va_profile.address.street,
        street2: nil,
        city: user.va_profile.address.city,
        state: user.va_profile.address.state,
        postal_code: user.va_profile.address.postal_code,
        country: user.va_profile.address.country
      },
      home_phone: user.va_profile.home_phone
    )
  end

  def generate_prefill(mappings)
    mappings.map do |k, v|
      method_chain = v.map(&:to_sym)
      { k.camelize(:lower) => call_methods(method_chain) }
    end.reduce({}, :merge)
  end

  def call_methods(methods)
    methods.inject(self) { |a, e| a.send e }
  rescue NoMethodError
    nil
  end
end
