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

  def self.merge(facilities, providers, center_x, center_y, limit)
    distance_facilities = facilities.map do |facility|
      { distance: 69 * Math.sqrt((facility.long - center_x)**2 + (facility.lat - center_y)**2),
        facility: facility }
    end
    result = []
    facility_ind = 0
    prov_ind = 0
    limit = facilities.length + providers.length if limit > facilities.length + providers.length
    while result.length < limit
      prov_remain = prov_ind < providers.length
      facility_empty = facility_ind >= distance_facilities.length
      # if there are providers left and either we're out of facilities or better than the next facility, pick provider
      if prov_remain && (facility_empty || distance_facilities[facility_ind][:distance] > providers[prov_ind].Miles)
        result.push providers[prov_ind]
        prov_ind += 1
      else
        result.push distance_facilities[facility_ind][:facility]
        facility_ind += 1
      end
    end
    result
  end
end
