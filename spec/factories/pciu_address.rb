# frozen_string_literal: true

FactoryBot.define do
  factory :pciu_address, class: 'EVSS::PCIUAddress::Address' do
    type ''
    address_effective_date '2017-08-07T19:43:59.383Z'
    address_one ''
    address_two ''
    address_three ''
  end
end

FactoryBot.define do
  factory :pciu_domestic_address, class: 'EVSS::PCIUAddress::DomesticAddress', parent: :pciu_address do
    type 'DOMESTIC'
    address_one '140 Rock Creek Church Rd NW'
    city 'Springfield'
    state_code 'OR'
    country_name 'USA'
    zip_code '97477'
    zip_suffix ''
  end
end

FactoryBot.define do
  factory :pciu_international_address, class: 'EVSS::PCIUAddress::InternationalAddress', parent: :pciu_address do
    type 'INTERNATIONAL'
    address_one '2 Avenue Gabriel'
    city 'Paris'
    country_name 'France'
  end
end

FactoryBot.define do
  factory :pciu_military_address, class: 'EVSS::PCIUAddress::MilitaryAddress', parent: :pciu_address do
    type 'MILITARY'
    address_one '57 Columbus Strassa'
    address_three 'Ben Franklin Village'
    military_post_office_type_code 'APO'
    military_state_code 'AE'
    zip_code '09028'
    zip_suffix '1234'
  end
end
