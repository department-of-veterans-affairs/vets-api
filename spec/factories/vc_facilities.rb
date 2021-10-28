# frozen_string_literal: true

FactoryBot.define do
  factory :vc_0543V, class: 'Facilities::VCFacility' do
    unique_id { '0543V' }
    name { 'Fort Collins Vet Center' }
    facility_type { 'vet_center' }
    classification { nil }
    website { nil }
    lat { 40.5528 }
    long { -105.09 }
    location { 'POINT(-105.09 40.5528)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '80526',
          'city' => 'Fort Collins',
          'state' => 'CO',
          'address_1' => '702 West Drake Road',
          'address_2' => 'Building C',
          'address_3' => nil
        } }
    }
    phone { { 'main' => '970-221-5176 x' } }
    hours {
      { 'friday' => '700AM-530PM',
        'monday' => '700AM-530PM',
        'sunday' => '-',
        'tuesday' => '700AM-800PM',
        'saturday' => '800AM-1200PM',
        'thursday' => '700AM-800PM',
        'wednesday' => '700AM-800PM' }
    }
    services { {} }
    feedback { {} }
    access { {} }
  end
  # bbox entries for PDX
  factory :vc_0617V, class: 'Facilities::VCFacility' do
    unique_id { '0617V' }
    name { 'Portland Vet Center' }
    facility_type { 'vet_center' }
    classification { nil }
    website { nil }
    lat { 45.5338 }
    long { -122.538 }
    location { 'POINT(-122.538 45.5338)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '97230',
          'city' => 'Portland',
          'state' => 'OR',
          'address_1' => '1505 NE 122nd Avenue',
          'address_2' => 'Suite 110',
          'address_3' => nil
        } }
    }
    phone { { 'main' => '503-688-5361 x' } }
    hours {
      { 'friday' => '800AM-800PM',
        'monday' => '800AM-730PM',
        'sunday' => '-',
        'tuesday' => '800AM-730PM',
        'saturday' => '-',
        'thursday' => '800AM-630PM',
        'wednesday' => '800AM-630PM' }
    }
    services { {} }
    feedback { {} }
    access { {} }
  end
end
