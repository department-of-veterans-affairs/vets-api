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
  attribute :MainPhone, String
  attribute :OrganizationFax, String
  attribute :ContactMethod, String
  attribute :IsAcceptingNewPatients, String
  attribute :ProviderGender, String
  attribute :ProviderSpecialties, Array
end
