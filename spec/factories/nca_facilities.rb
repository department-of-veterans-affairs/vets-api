# frozen_string_literal: true

FactoryBot.define do
  factory :nca_888, class: 'Facilities::NCAFacility' do
    unique_id { '888' }
    name { 'Fort Logan National Cemetery' }
    facility_type { 'va_cemetery' }
    classification { 'National Cemetery' }
    website { 'https://www.cem.va.gov/cems/nchp/ftlogan.asp' }
    lat { 39.6455740260001 }
    long { -105.052859396 }
    location { 'POINT(-105.052859396 39.6455740260001)' }
    address {
      { 'mailing' => {
        'zip' => '80236',
        'city' => 'Denver',
        'state' => 'CO',
        'address_1' => '4400 W Kenyon Ave',
        'address_2' => nil,
        'address_3' => nil
      },
        'physical' => {
          'zip' => '80236',
          'city' => 'Denver',
          'state' => 'CO',
          'address_1' => '4400 W Kenyon Ave',
          'address_2' => nil,
          'address_3' => nil
        } }
    }
    phone { { 'fax' => '303-781-9378', 'main' => '303-761-0117' } }
    hours {
      { 'Friday' => 'Sunrise - Sunset',
        'Monday' => 'Sunrise - Sunset',
        'Sunday' => 'Sunrise - Sunset',
        'Tuesday' => 'Sunrise - Sunset',
        'Saturday' => 'Sunrise - Sunset',
        'Thursday' => 'Sunrise - Sunset',
        'Wednesday' => 'Sunrise - Sunset' }
    }
    services { {} }
    feedback { {} }
    access { {} }
  end
  factory :nca_907, class: 'Facilities::NCAFacility' do
    unique_id { '907' }
    name { 'Willamette National Cemetery' }
    facility_type { 'va_cemetery' }
    classification { 'National Cemetery' }
    website { 'https://www.cem.va.gov/cems/nchp/willamette.asp' }
    lat { 45.4568385960001 }
    long { -122.540844696 }
    location { 'POINT(-122.540844696 45.4568385960001)' }
    address {
      { 'mailing' => {
        'zip' => '97086-6937',
        'city' => 'Portland',
        'state' => 'OR',
        'address_1' => '11800 SE Mt Scott Blvd',
        'address_2' => nil,
        'address_3' => nil
      },
        'physical' => {
          'zip' => '97086-6937',
          'city' => 'Portland',
          'state' => 'OR',
          'address_1' => '11800 SE Mt Scott Blvd',
          'address_2' => nil,
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '503-273-5251',
        'main' => '503-273-5250' }
    }
    hours {
      { 'Friday' => '7:00am - 5:00pm',
        'Monday' => '7:00am - 5:00pm',
        'Sunday' => '7:00am - 5:00pm',
        'Tuesday' => '7:00am - 5:00pm',
        'Saturday' => '7:00am - 5:00pm',
        'Thursday' => '7:00am - 5:00pm',
        'Wednesday' => '7:00am - 5:00pm' }
    }
    services { {} }
    feedback { {} }
    access { {} }
  end
  # bbox entries for NY nca
  factory :nca_824, class: 'Facilities::NCAFacility' do
    unique_id { '824' }
    name { 'Woodlawn National Cemetery' }
    facility_type { 'va_cemetery' }
    classification { 'National Cemetery' }
    website { 'https://www.cem.va.gov/cems/nchp/woodlawn.asp' }
    lat { 42.111095628 }
    long { -76.8265631089999 }
    location { 'POINT(-76.8265631089999 42.111095628)' }
    address {
      { 'mailing' => {
        'zip' => '14810',
        'city' => 'Bath',
        'state' => 'NY',
        'address_1' => 'VA Medical Center',
        'address_2' => nil,
        'address_3' => nil
      },
        'physical' => {
          'zip' => '14901',
          'city' => 'Elmira',
          'state' => 'NY',
          'address_1' => '1825 Davis St',
          'address_2' => nil,
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '607-732-1769',
        'main' => '607-732-5411' }
    }
    hours {
      { 'Friday' => 'Sunrise - Sunset',
        'Monday' => 'Sunrise - Sunset',
        'Sunday' => 'Sunrise - Sunset',
        'Tuesday' => 'Sunrise - Sunset',
        'Saturday' => 'Sunrise - Sunset',
        'Thursday' => 'Sunrise - Sunset',
        'Wednesday' => 'Sunrise - Sunset' }
    }
    services { {} }
    feedback { {} }
    access { {} }
  end
  factory :nca_088, class: 'Facilities::NCAFacility' do
    unique_id { '088' }
    name { "Albany Rural Cemetery Soldiers' Lot" }
    facility_type { 'va_cemetery' }
    classification { 'Rural' }
    website { nil }
    lat { 42.7038448500001 }
    long { -73.72356501 }
    location { 'POINT(-73.72356501 42.7038448500001)' }
    address {
      { 'mailing' => {
        'zip' => '12871-1721',
        'city' => 'Schuylerville',
        'state' => 'NY',
        'address_1' => '200 Duell Road',
        'address_2' => nil,
        'address_3' => nil
      },
        'physical' => {
          'zip' => '12204',
          'city' => 'Albany',
          'state' => 'NY',
          'address_1' => 'Cemetery Avenue',
          'address_2' => nil,
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '5184630787',
        'main' => '5184637017' }
    }
    hours {
      { 'Friday' => 'Sunrise - Sundown',
        'Monday' => 'Sunrise - Sundown',
        'Sunday' => 'Sunrise - Sundown',
        'Tuesday' => 'Sunrise - Sundown',
        'Saturday' => 'Sunrise - Sundown',
        'Thursday' => 'Sunrise - Sundown',
        'Wednesday' => 'Sunrise - Sundown' }
    }
    services { {} }
    feedback { {} }
    access { {} }
  end
  factory :nca_808, class: 'Facilities::NCAFacility' do
    unique_id { '808' }
    name { 'Cypress Hills National Cemetery' }
    facility_type  { 'va_cemetery' }
    classification { 'National Cemetery' }
    website { 'https://www.cem.va.gov/cems/nchp/cypresshills.asp' }
    lat { 40.6859544970001 }
    long { -73.8812331729999 }
    location { 'POINT(-73.8812331729999 40.6859544970001)' }
    address {
      { 'mailing' => {
        'zip' => '11208',
        'city' => 'Farmingdale',
        'state' => 'NY',
        'address_1' => '2040 Wellwood Ave',
        'address_2' => nil,
        'address_3' => nil
      },
        'physical' => {
          'zip' => '11208',
          'city' => 'Brooklyn',
          'state' => 'NY',
          'address_1' => '625 Jamaica Ave',
          'address_2' => nil,
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '631-694-5422',
        'main' => '631-454-4949' }
    }
    hours {
      { 'Friday' => '8:00am - 4:30pm',
        'Monday' => '8:00am - 4:30pm',
        'Sunday' => '8:00am - 4:30pm',
        'Tuesday' => '8:00am - 4:30pm',
        'Saturday' => '8:00am - 4:30pm',
        'Thursday' => '8:00am - 4:30pm',
        'Wednesday' => '8:00am - 4:30pm' }
    }
    services { {} }
    feedback { {} }
    access { {} }
  end
  factory :nca_803, class: 'Facilities::NCAFacility' do
    unique_id { '803' }
    name { 'Bath National Cemetery' }
    facility_type { 'va_cemetery' }
    classification { 'National Cemetery' }
    website { 'https://www.cem.va.gov/cems/nchp/bath.asp' }
    lat { 42.347251468 }
    long { -77.350304205 }
    location { 'POINT(-77.350304205 42.347251468)' }
    address {
      { 'mailing' => {
        'zip' => '14810',
        'city' => 'Bath',
        'state' => 'NY',
        'address_1' => 'VA Medical Center',
        'address_2' => nil,
        'address_3' => nil
      },
        'physical' => {
          'zip' => '14810',
          'city' => 'Bath',
          'state' => 'NY',
          'address_1' => 'VA Medical Center',
          'address_2' => nil,
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '607-664-4761',
        'main' => '607-664-4806' }
    }
    hours {
      { 'Friday' => 'Sunrise - Sunset',
        'Monday' => 'Sunrise - Sunset',
        'Sunday' => 'Sunrise - Sunset',
        'Tuesday' => 'Sunrise - Sunset',
        'Saturday' => 'Sunrise - Sunset',
        'Thursday' => 'Sunrise - Sunset',
        'Wednesday' => 'Sunrise - Sunset' }
    }
    services { {} }
    feedback { {} }
    access { {} }
  end
  factory :nca_917, class: 'Facilities::NCAFacility' do
    unique_id { '917' }
    name { 'Gerald B.H. Solomon Saratoga National Cemetery' }
    facility_type { 'va_cemetery' }
    classification { 'National Cemetery' }
    website { 'https://www.cem.va.gov/cems/nchp/geraldbhsolomonsaratoga.asp' }
    lat { 43.026389889 }
    long { -73.617079936 }
    location { 'POINT(-73.617079936 43.026389889)' }
    address {
      { 'mailing' => {
        'zip' => '12871-1721',
        'city' => 'Schuylerville',
        'state' => 'NY',
        'address_1' => '200 Duell Rd',
        'address_2' => nil,
        'address_3' => nil
      },
        'physical' => {
          'zip' => '12871-1721',
          'city' => 'Schuylerville',
          'state' => 'NY',
          'address_1' => '200 Duell Rd',
          'address_2' => nil,
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '518-583-6975',
        'main' => '518-581-9128' }
    }
    hours {
      { 'Friday' => 'Sunrise - Sunset',
        'Monday' => 'Sunrise - Sunset',
        'Sunday' => 'Sunrise - Sunset',
        'Tuesday' => 'Sunrise - Sunset',
        'Saturday' => 'Sunrise - Sunset',
        'Thursday' => 'Sunrise - Sunset',
        'Wednesday' => 'Sunrise - Sunset' }
    }
    services { {} }
    feedback { {} }
    access { {} }
  end
  factory :nca_815, class: 'Facilities::NCAFacility' do
    unique_id { '815' }
    name { 'Long Island National Cemetery' }
    facility_type { 'va_cemetery' }
    classification { 'National Cemetery' }
    website { 'https://www.cem.va.gov/cems/nchp/longisland.asp' }
    lat { 40.750563679 }
    long { -73.401496373 }
    location { 'POINT(-73.401496373 40.750563679)' }
    address {
      { 'mailing' => {
        'zip' => '11735-1211',
        'city' => 'Farmingdale',
        'state' => 'NY',
        'address_1' => '2040 Wellwood Ave',
        'address_2' => nil,
        'address_3' => nil
      },
        'physical' => {
          'zip' => '11735-1211',
          'city' => 'Farmingdale',
          'state' => 'NY',
          'address_1' => '2040 Wellwood Ave',
          'address_2' => nil,
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '631-694-5422',
        'main' => '631-454-4949' }
    }
    hours {
      { 'Friday' => '7:30am - 5:00pm',
        'Monday' => '7:30am - 5:00pm',
        'Sunday' => '7:30am - 5:00pm',
        'Tuesday' => '7:30am - 5:00pm',
        'Saturday' => '7:30am - 5:00pm',
        'Thursday' => '7:30am - 5:00pm',
        'Wednesday' => '7:30am - 5:00pm' }
    }
    services { {} }
    feedback { {} }
    access { {} }
  end
end
