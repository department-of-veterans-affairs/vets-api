# frozen_string_literal: true

require 'common/models/base'

class PPMS::Provider < Common::Base
  attribute :acc_new_patients, String
  attribute :address_city, String
  attribute :address_postal_code, String
  attribute :address_state_province, String
  attribute :address_street, String
  attribute :care_site, String
  attribute :caresite_phone, String
  attribute :contact_method, String
  attribute :email, String
  attribute :fax, String
  attribute :gender, String
  attribute :id, String
  attribute :latitude, Float
  attribute :longitude, Float
  attribute :main_phone, String
  attribute :miles, Float
  attribute :name, String
  attribute :pos_codes, String
  attribute :provider_identifier, String
  attribute :provider_name, String
  attribute :provider_type, String
  attribute :specialties, Array

  def initialize(attr = {})
    super(attr)
    new_attr = attr.dup.transform_keys { |k| k.to_s.snakecase.to_sym }
    new_attr[:acc_new_patients] ||= new_attr.delete(:is_accepting_new_patients)
    new_attr[:acc_new_patients] ||= new_attr.delete(:provider_accepting_new_patients)

    new_attr = cleanup_address_attributes(new_attr)

    new_attr[:caresite_phone] ||= new_attr.delete(:care_site_phone_number)
    new_attr[:contact_method] ||= new_attr.delete(:contact_method)
    new_attr[:email] ||= new_attr.delete(:email)
    new_attr[:fax] ||= new_attr.delete(:fax)
    new_attr[:fax] ||= new_attr.delete(:organization_fax)
    new_attr[:gender] ||= new_attr.delete(:provider_gender)
    new_attr[:id] ||= new_attr.delete(:provider_hexdigest) || new_attr[:provider_identifier]
    new_attr[:main_phone] ||= new_attr.delete(:main_phone)
    new_attr[:phone] ||= new_attr.delete(:main_phone)
    new_attr[:provider_type] ||= new_attr.delete(:provider_type)

    new_attr = cleanup_specialties(new_attr)

    self.attributes = new_attr
  end

  def set_hexdigest_as_id!
    self.id = Digest::SHA256.hexdigest(attributes.except(:id).to_a.join('|'))
  end

  def set_group_practive_or_agency!
    self.provider_type = 'GroupPracticeOrAgency'
  end

  def add_details(prov_info)
    new_attr = prov_info.attributes.dup.transform_keys { |k| k.to_s.snakecase.to_sym }.slice(
      :contact_method,
      :email,
      :main_phone,
      :fax,
      :specialties,
      :provider_type
    )

    self.attributes = attributes.merge(new_attr)
  end

  def add_provider_service(provider_service)
    new_attr = provider_service.attributes.dup.transform_keys { |k| k.to_s.snakecase.to_sym }.slice(
      :address_city,
      :address_postal_code,
      :address_state_province,
      :address_street,
      :latitude,
      :longitude
    )

    self.attributes = attributes.merge(new_attr)
  end

  def specialty_ids
    specialties.collect(&:specialty_code)
  end

  private

  def cleanup_address_attributes(new_attr)
    new_attr[:address_city] ||= new_attr.delete(:care_site_address_city)
    new_attr[:address_postal_code] ||= new_attr.delete(:care_site_address_zip_code)
    new_attr[:address_state_province] ||= new_attr.delete(:care_site_address_state)
    new_attr[:address_street] ||= new_attr.delete(:care_site_address_street)
    new_attr
  end

  def cleanup_specialties(new_attr)
    new_attr[:specialties] ||= new_attr.delete(:provider_specialties)&.collect do |specialty|
      PPMS::Specialty.new(
        specialty.transform_keys { |k| k.to_s.snakecase.to_sym }
      )
    end
    new_attr
  end
end
