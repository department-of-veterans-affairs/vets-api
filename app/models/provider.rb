# frozen_string_literal: true

require 'common/models/base'
# Provider Model
class Provider < Common::Base
  attribute :AddressCity, String
  attribute :AddressPostalCode, String
  attribute :AddressStateProvince, String
  attribute :AddressStreet, String
  attribute :CareSite, String
  attribute :CareSitePhoneNumber, String
  attribute :ContactMethod, String
  attribute :Email, String
  attribute :IsAcceptingNewPatients, String
  attribute :Latitude, Float
  attribute :Longitude, Float
  attribute :MainPhone, String
  attribute :Miles, Float
  attribute :Name, String
  attribute :OrganizationFax, String
  attribute :posCodes, String
  attribute :ProviderGender, String
  attribute :ProviderIdentifier, String
  attribute :ProviderHexdigest, String
  attribute :ProviderName, String
  attribute :ProviderSpecialties, Array
  attribute :ProviderType, String

  def <=>(other)
    self.Miles <=> other.Miles
  end

  def hexdigest
    Digest::SHA256.hexdigest(attributes.except(:ProviderHexdigest).to_a.join('|'))
  end

  def set_hexdigest!
    self.ProviderHexdigest = hexdigest
  end

  def id
    self.ProviderHexdigest || self.ProviderIdentifier
  end

  def self.from_provloc(prov_loc)
    provider = Provider.new(prov_loc)
    provider.AddressCity = prov_loc['CareSiteAddressCity']
    provider.AddressPostalCode = prov_loc['CareSiteAddressZipCode']
    provider.AddressStateProvince = prov_loc['CareSiteAddressState']
    provider.AddressStreet = prov_loc['CareSiteAddressStreet']
    provider.CareSite = prov_loc['CareSite']
    provider.CareSitePhoneNumber = prov_loc['CareSitePhoneNumber']
    provider.IsAcceptingNewPatients = prov_loc['ProviderAcceptingNewPatients']
    provider.ProviderName = prov_loc['ProviderName']
    provider.Name = prov_loc['Name']
    provider
  end

  def add_details(prov_info)
    self.ContactMethod = prov_info['ContactMethod']
    self.Email = prov_info['Email']
    self.MainPhone = prov_info['MainPhone']
    self.OrganizationFax = prov_info['OrganizationFax']
    self.ProviderSpecialties = prov_info['ProviderSpecialties']
    self.ProviderType = prov_info['ProviderType']
  end

  def add_provider_service(provider_service)
    self.AddressCity = provider_service['CareSiteAddressCity']
    self.AddressPostalCode = provider_service['CareSiteAddressZipCode']
    self.AddressStateProvince = provider_service['CareSiteAddressState']
    self.AddressStreet = provider_service['CareSiteAddressStreet']
    self.Latitude = provider_service['Latitude']
    self.Longitude = provider_service['Longitude']
  end
end
