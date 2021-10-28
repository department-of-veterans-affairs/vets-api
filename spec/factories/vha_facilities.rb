# frozen_string_literal: true

FactoryBot.define do
  factory :vha_648A4, class: 'Facilities::VHAFacility' do
    unique_id { '648A4' }
    name { 'Portland VA Medical Center-Vancouver' }
    facility_type { 'va_health_facility' }
    classification { 'VA Medical Center (VAMC)' }
    website { 'http://www.portland.va.gov/locations/vancouver.asp' }
    mobile { false }
    active_status { 'A' }
    visn { '20' }
    lat { 45.6394162600001 }
    long { -122.65528736 }
    location { 'POINT(-122.65528736 45.6394162600001)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '98661-3753',
          'city' => 'Vancouver',
          'state' => 'WA',
          'address_1' => '1601 East 4th Plain Boulevard',
          'address_2' => nil,
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '360-690-0864',
        'main' => '360-759-1901',
        'pharmacy' => '503-273-5183',
        'after_hours' => '360-696-4061',
        'patient_advocate' => '503-273-5308',
        'mental_health_clinic' => '503-273-5187',
        'enrollment_coordinator' => '503-273-5069' }
    }
    hours {
      { 'Friday' => '730AM-430PM',
        'Monday' => '730AM-430PM',
        'Sunday' => '-',
        'Tuesday' => '730AM-630PM',
        'Saturday' => '800AM-1000AM',
        'Thursday' => '730AM-430PM',
        'Wednesday' => '730AM-430PM' }
    }
    services {
      { 'health' => [
        { 'sl1' => ['DentalServices'],
          'sl2' => [] },
        { 'sl1' => ['MentalHealthCare'],
          'sl2' => [] },
        { 'sl1' => ['PrimaryCare'],
          'sl2' => [] }
      ],
        'last_updated' => '2018-03-15' }
    }
    feedback {
      { 'health' => {
        'effective_date' => '2017-08-15',
        'primary_care_urgent' => 0.8,
        'primary_care_routine' => 0.84
      } }
    }
    access {
      { 'health' => {
        'audiology' => {
          'new' => 35.0,
          'established' => 18.0
        },
        'optometry' => {
          'new' => 38.0,
          'established' => 22.0
        },
        'dermatology' => {
          'new' => 4.0,
          'established' => nil
        },
        'ophthalmology' => {
          'new' => 1.0,
          'established' => 4.0
        },
        'primary_care' => {
          'new' => 34.0,
          'established' => 5.0
        },
        'mental_health' => {
          'new' => 12.0,
          'established' => 3.0
        },
        'effective_date' => '2018-02-26'
      } }
    }
  end
  # bbox entries for PDX
  factory :vha_648, class: 'Facilities::VHAFacility' do
    unique_id { '648' }
    name { 'Portland VA Medical Center' }
    facility_type { 'va_health_facility' }
    classification { 'VA Medical Center (VAMC)' }
    website { 'http://www.portland.va.gov/' }
    visn { '20' }
    lat { 45.4974614500001 }
    long { -122.68287208 }
    location { 'POINT(-122.68287208 45.4974614500001)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '97239-2964',
          'city' => 'Portland',
          'state' => 'OR',
          'address_1' => '3710 Southwest US Veterans Hospital Road',
          'address_2' => nil,
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '503-273-5319',
        'main' => '503-721-1498',
        'pharmacy' => '503-273-5183',
        'after_hours' => '503-220-8262',
        'patient_advocate' => '503-273-5308',
        'mental_health_clinic' => '503-273-5187',
        'enrollment_coordinator' => '503-273-5069' }
    }
    hours {
      { 'Friday' => '24/7',
        'Monday' => '24/7',
        'Sunday' => '24/7',
        'Tuesday' => '24/7',
        'Saturday' => '24/7',
        'Thursday' => '24/7',
        'Wednesday' => '24/7' }
    }
    services {
      { 'health' => [
        { 'sl1' => ['DentalServices'],
          'sl2' => [] },
        { 'sl1' => ['MentalHealthCare'],
          'sl2' => [] },
        { 'sl1' => ['PrimaryCare'],
          'sl2' => [] },
        { 'sl1' => ['EmergencyCare'],
          'sl2' => [] },
        { 'sl1' => ['UrgentCare'],
          'sl2' => [] },
        { 'sl1' => ['Audiology'],
          'sl2' => [] },
        { 'sl1' => ['Optometry'],
          'sl2' => [] }
      ],
        'last_updated' => '2018-03-15' }
    }
    feedback {
      { 'health' => {
        'effective_date' => '2017-08-15',
        'primary_care_urgent' => 0.73,
        'primary_care_routine' => 0.82,
        'specialty_care_urgent' => 0.75,
        'specialty_care_routine' => 0.82
      } }
    }
    access {
      { 'health' => {
        'audiology' => {
          'new' => 26.0,
          'established' => 12.0
        },
        'optometry' => {
          'new' => 64.0,
          'established' => 27.0
        },
        'cardiology' => {
          'new' => 18.0,
          'established' => 8.0
        },
        'gynecology' => {
          'new' => 18.0,
          'established' => 6.0
        },
        'dermatology' => {
          'new' => 17.0,
          'established' => 6.0
        },
        'orthopedics' => {
          'new' => 26.0,
          'established' => 9.0
        },
        'ophthalmology' => {
          'new' => 18.0,
          'established' => 8.0
        },
        'primary_care' => {
          'new' => 27.0,
          'established' => 6.0
        },
        'mental_health' => {
          'new' => 13.0,
          'established' => 1.0
        },
        'womens_health' => {
          'new' => 15.0,
          'established' => 5.0
        },
        'effective_date' => '2018-03-05',
        'urology' => {
          'new' => 24.0,
          'established' => 8.0
        },
        'gastroenterology' => {
          'new' => 24.0,
          'established' => 13.0
        }
      } }
    }
  end
  factory :vha_648GI, class: 'Facilities::VHAFacility' do
    unique_id { '648GI' }
    name { 'Portland VA Clinic' }
    facility_type { 'va_health_facility' }
    classification { 'Primary Care CBOC' }
    website { nil }
    mobile { false }
    active_status { 'A' }
    visn { '20' }
    lat { 45.52017304 }
    long { -122.67221794 }
    location { 'POINT(-122.67221794 45.52017304)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '97204-3432',
          'city' => 'Portland',
          'state' => 'OR',
          'address_1' => '308 Southwest 1st Avenue',
          'address_2' => 'Lawrence Building',
          'address_3' => 'Suite 155'
        } }
    }
    phone {
      { 'fax' => '503-808-1900',
        'main' => '503-808-1256',
        'pharmacy' => '503-273-5183',
        'after_hours' => '800-273-8255',
        'patient_advocate' => '503-273-5308',
        'mental_health_clinic' => '',
        'enrollment_coordinator' => '503-273-5069' }
    }
    hours {
      { 'Friday' => '800AM-430PM',
        'Monday' => '800AM-430PM',
        'Sunday' => '-',
        'Tuesday' => '800AM-430PM',
        'Saturday' => '-',
        'Thursday' => '800AM-430PM',
        'Wednesday' => '800AM-430PM' }
    }
    services {
      { 'health' => [
        {
          'sl1' => [
            'MentalHealthCare'
          ],
          'sl2' => []
        },
        {
          'sl1' => [
            'PrimaryCare'
          ],
          'sl2' => []
        }
      ],
        'last_updated' => '2018-03-15' }
    }
    feedback { { 'health' => {} } }
    access {
      { 'health' => {
        'primary_care' => {
          'new' => 12.0,
          'established' => 2.0
        },
        'effective_date' => '2018-03-05'
      } }
    }
  end
  factory :vha_402QA, class: 'Facilities::VHAFacility' do
    unique_id { '402QA' }
    name { 'Fort Kent VA Clinic' }
    facility_type { 'va_health_facility' }
    classification { 'Other Outpatient Services (OOS)' }
    website { nil }
    visn { '1' }
    lat { 47.26560990000007 }
    long { -68.59126328999997 }
    location { 'POINT(-68.59126328999997, 47.26560990000007)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '04743-1409',
          'city' => 'Fort Kent',
          'state' => 'ME',
          'address_1' => '197 East Main Street',
          'address_2' => 'Medical Office Building',
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '207-834-2351',
        'main' => '207-834-1572',
        'pharmacy' => '207-623-5353',
        'after_hours' => '844-750-8426',
        'patient_advocate' => '207-623-5760',
        'mental_health_clinic' => '',
        'enrollment_coordinator' => '207-623-8411 x5688' }
    }
    hours {
      { 'Friday' => 'Closed',
        'Monday' => 'Closed',
        'Sunday' => 'Closed',
        'Tuesday' => 'Closed',
        'Saturday' => 'Closed',
        'Thursday' => '800AM-430PM',
        'Wednesday' => 'Closed' }
    }
    services {
      { 'other' => [
        {
          'sl1' => [
            'Online Scheduling'
          ],
          'sl2' => []
        }
      ],
        'health' => [],
        'last_updated' => '2019-06-04' }
    }
    feedback { { 'health' => {} } }
    access {
      { 'health' => {
        'primary_care' => {
          'new' => nil,
          'established' => 4.807692
        },
        'effective_date' => '2018-05-27'
      } }
    }
  end
  factory :generic_vha, class: 'Facilities::VHAFacility' do
    sequence :unique_id, &:to_s
    name { 'Generic Health Office' }
    facility_type { 'va_health_facility' }
    classification { 'VA Medical Center (VAMC)' }
    website { 'http://www.health.va.gov/generic' }
    mobile { false }
    active_status { 'A' }
    visn { '1' }
    lat { 45.6394162600001 }
    long { -122.65528736 }
    location { 'POINT(-122.65528736 45.6394162600001)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '98661-3753',
          'city' => 'Vancouver',
          'state' => 'WA',
          'address_1' => '100 Generic Street',
          'address_2' => nil,
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '555-555-5555 x',
        'main' => '555-555-5555 x',
        'pharmacy' => '555-555-5555 x',
        'after_hours' => '555-555-5555 x',
        'patient_advocate' => '555-555-5555 x',
        'mental_health_clinic' => '555-555-5555',
        'enrollment_coordinator' => '555-555-5555 x' }
    }
    hours {
      { 'Friday' => '730AM-430PM',
        'Monday' => '730AM-430PM',
        'Sunday' => '-',
        'Tuesday' => '730AM-630PM',
        'Saturday' => '800AM-1000AM',
        'Thursday' => '730AM-430PM',
        'Wednesday' => '730AM-430PM' }
    }
    services {
      { 'health' => [
        { 'sl1' => ['DentalServices'],
          'sl2' => [] },
        { 'sl1' => ['MentalHealthCare'],
          'sl2' => [] },
        { 'sl1' => ['PrimaryCare'],
          'sl2' => [] }
      ],
        'last_updated' => '2018-03-15' }
    }
    feedback {
      { 'health' => {
        'effective_date' => '2017-08-15',
        'primary_care_urgent' => 0.8,
        'primary_care_routine' => 0.84
      } }
    }
    access {
      { 'health' => {
        'audiology' => {
          'new' => 35.0,
          'established' => 18.0
        },
        'optometry' => {
          'new' => 38.0,
          'established' => 22.0
        },
        'dermatology' => {
          'new' => 4.0,
          'established' => nil
        },
        'ophthalmology' => {
          'new' => 1.0,
          'established' => 4.0
        },
        'primary_care' => {
          'new' => 34.0,
          'established' => 5.0
        },
        'mental_health' => {
          'new' => 12.0,
          'established' => 3.0
        },
        'effective_date' => '2018-02-26'
      } }
    }
  end
end
