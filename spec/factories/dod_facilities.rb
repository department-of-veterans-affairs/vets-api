# frozen_string_literal: true

FactoryBot.define do
  factory :dod_001, class: 'Facilities::DODFacility' do
    unique_id { SecureRandom.uuid }
    name { 'Portland Army Medical Center' }
    facility_type { 'dod_health' }
    lat { 0.0 }
    long { 0.0 }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => nil,
          'city' => 'Portland',
          'state' => 'OR',
          'country' => 'USA',
          'address_1' => nil,
          'address_2' => nil,
          'address_3' => nil
        } }
    }
  end
  factory :dod_002, class: 'Facilities::DODFacility' do
    unique_id { SecureRandom.uuid }
    name { 'Portland Naval Hospital' }
    facility_type { 'dod_health' }
    lat { 0.0 }
    long { 0.0 }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => nil,
          'city' => 'Portland',
          'state' => 'OR',
          'country' => 'USA',
          'address_1' => nil,
          'address_2' => nil,
          'address_3' => nil
        } }
    }
  end
end
