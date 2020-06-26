require 'common/models/base'

class PPMS::Provider < Common::Base
  include ActiveModel::Serializers::JSON

  attribute :acc_new_patients, String
  attribute :address, Hash
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
  attribute :provider_specialties, Array
  attribute :provider_type, String

  def initialize(attr)
    super(attr)
    new_attr = attr.dup
    new_attr[:acc_new_patients] = new_attr.delete(:is_accepting_new_patients)
    new_attr[:caresite_phone] = new_attr.delete(:care_site_phone_number)
    new_attr[:fax] = new_attr.delete(:organization_fax)
    new_attr[:gender] = new_attr.delete(:provider_gender)
    new_attr[:phone] = new_attr.delete(:main_phone)
    new_attr[:id] = new_attr.delete(:provider_hexdigest) || new_attr[:provider_identifier]

    self.attributes = new_attr
  end
end
