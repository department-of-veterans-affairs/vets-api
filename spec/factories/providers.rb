# frozen_string_literal: true

FactoryBot.define do
  factory :provider, class: Provider do
    ProviderIdentifier { '111111' }
    Name { 'Allergy Partners of Manassas' }
    Latitude { 38.8476575 }
    Longitude { -72.26950512 }
    AddressStreet { '700 Centreville Rd' }
    AddressCity { 'Manassas' }
    AddressStateProvince { 'VA' }
    AddressPostalCode { '22033' }
    MainPhone { '703-823-8551' }
    ProviderSpecialties { [] }
  end
end
