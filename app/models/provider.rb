# frozen_string_literal: true

require 'common/models/base'
# Provider Model
class Provider < Common::Base
  attribute :ProviderIdentifier, String
  attribute :Name, String
  attribute :AddressStreet, String
  attribute :AddressCity, String
  attribute :AddressStateProvince, String
  attribute :AddressPostalCode, String
  attribute :Email, String
  attribute :MainPhone, String
  atribute  :CareSitePhoneNumber, String
  attribute :OrganizationFax, String
  attribute :ContactMethod, String
  attribute :IsAcceptingNewPatients, String
  attribute :ProviderGender, String
  attribute :ProviderSpecialties, Array
  attribute :Latitude, Float
  attribute :Longitude, Float
  attribute :Miles, Float

  def self.from_provloc(prov_loc)
    provider = Provider.new(prov_loc)
    provider.Name = prov_loc['ProviderName']
    provider.IsAcceptingNewPatients = prov_loc['ProviderAcceptingNewPatients']
    provider.CareSitePhoneNumber = prov_loc['CareSitePhoneNumber']
    provider.AddressStreet = prov_loc['CareSiteAddressStreet']
    provider.AddressCity = prov_loc['CareSiteAddressCity']
    provider.AddressStateProvince = prov_loc['CareSiteAddressState']
    provider.AddressPostalCode = prov_loc['CareSiteAddressZipCode']
    provider
  end

  def add_details(prov_info)
    self.Email = prov_info['Email']
    self.MainPhone = prov_info['MainPhone']
    self.OrganizationFax = prov_info['OrganizationFax']
    self.ContactMethod = prov_info['ContactMethod']
    self.ProviderSpecialties = prov_info['ProviderSpecialties']
  end

  def add_provider_service(provider_service)
    self.AddressStreet = provider_service['CareSiteAddressStreet']
    self.AddressCity = provider_service['CareSiteAddressCity']
    self.AddressPostalCode = provider_service['CareSiteAddressZipCode']
    self.AddressStateProvince = provider_service['CareSiteAddressState']
    self.Longitude = provider_service['Longitude']
    self.Latitude = provider_service['Latitude']
  end
end
