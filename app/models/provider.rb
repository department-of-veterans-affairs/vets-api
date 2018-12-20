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
    provider.AddressStreet = prov_loc['CareSiteAddress']
    provider
  end

  def add_details(prov_info)
    self.AddressStreet = prov_info['AddressStreet'] unless prov_info['AddressStreet'].nil?
    self.AddressCity = prov_info['AddressCity']
    self.AddressStateProvince = prov_info['AddressStateProvince']
    self.AddressPostalCode = prov_info['AddressPostalCode']
    self.Email = prov_info['Email']
    self.MainPhone = prov_info['MainPhone']
    self.OrganizationFax = prov_info['OrganizationFax']
    self.ContactMethod = prov_info['ContactMethod']
    self.ProviderSpecialties = prov_info['ProviderSpecialties']
  end

  def add_caresite(caresite)
    self.AddressStreet = caresite['Street']
    self.AddressCity = caresite['City']
    self.AddressPostalCode = caresite['ZipCode']
    self.AddressStateProvince = caresite['State']
    self.Longitude = caresite['Longitude']
    self.Latitude = caresite['Latitude']
  end
end
