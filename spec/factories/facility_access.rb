# frozen_string_literal: true

FactoryBot.define do
  factory :access_satisfaction, class: 'FacilitySatisfaction' do
    station_number '648'
    metrics do
      {
        primary_care_urgent: 0.71890521049499512,
        primary_care_routine: 0.81882423162460327,
        specialty_care_routine: 0.79339683055877686,
        specialty_care_urgent: 0.68941879272460938
      }
    end
    source_updated '2017-03-24T21:30:58'
    local_updated '2017-06-12T21:04:54Z'
  end

  factory :access_wait_time, class: 'FacilityWaitTime' do
    station_number '648'
    metrics do
      {
        primary_care: { 'new' => 35.0, 'established' => 9.0 },
        mental_health: { 'new' => 17.0, 'established' => 1.0 },
        audiology: { 'new' => 29.0, 'established' => 17.0 },
        womens_health: { 'new' => nil, 'established' => 11.0 },
        opthalmology: { 'new' => 21.0, 'established' => 8.0 },
        urology_clinic: { 'new' => 20.0, 'established' => 7.0 }
      }
    end
    source_updated '2017-03-31T00:00:00'
    local_updated  '2017-06-12T21:04:58Z'
  end

  factory :vha_648A4, class: Facilities::VHAFacility do
    unique_id '648A4'
    name 'Portland VA Medical Center-Vancouver'
    facility_type 'va_health_facility'
    classification 'VA Medical Center (VAMC)'
    website 'http://www.portland.va.gov/locations/vancouver.asp'
    lat 45.6394162600001
    long(-122.65528736)
    address('mailing' => {},
            'physical' => {
              'zip' => '98661-3753',
              'city' => 'Vancouver',
              'state' => 'WA',
              'address_1' => '1601 East 4th Plain Boulevard',
              'address_2' => nil,
              'address_3' => nil
            })
    phone('fax' => '360-690-0864 x',
          'main' => '360-759-1901 x',
          'pharmacy' => '503-273-5183 x',
          'after_hours' => '360-696-4061 x',
          'patient_advocate' => '503-273-5308 x',
          'mental_health_clinic' => '503-273-5187',
          'enrollment_coordinator' => '503-273-5069 x')
    hours('Friday' => '730AM-430PM',
          'Monday' => '730AM-430PM',
          'Sunday' => '-',
          'Tuesday' => '730AM-630PM',
          'Saturday' => '800AM-1000AM',
          'Thursday' => '730AM-430PM',
          'Wednesday' => '730AM-430PM')
    services('health' => [
               { 'sl1' => ['DentalServices'],
                 'sl2' => [] },
               { 'sl1' => ['MentalHealthCare'],
                 'sl2' => [] },
               { 'sl1' => ['PrimaryCare'],
                 'sl2' => [] }
             ],
             'last_updated' => '2018-03-15')
    feedback('health' => {
               'effective_date' => '2017-08-15',
               'primary_care_urgent' => '0.8',
               'primary_care_routine' => '0.84'
             })
    access('health' => {
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
             'opthalmology' => {
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
           })
  end

  factory :nca_888, class: Facilities::NCAFacility do
    unique_id '888'
    name 'Fort Logan National Cemetery'
    facility_type 'va_cemetery'
    classification 'National Cemetery'
    website 'https://www.cem.va.gov/cems/nchp/ftlogan.asp'
    lat 39.6455740260001
    long(-105.052859396)
    address 'mailing' => {
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
            }
    phone 'fax' => '303-781-9378', 'main' => '303-761-0117'
    hours 'Friday' => 'Sunrise - Sunset',
          'Monday' => 'Sunrise - Sunset',
          'Sunday' => 'Sunrise - Sunset',
          'Tuesday' => 'Sunrise - Sunset',
          'Saturday' => 'Sunrise - Sunset',
          'Thursday' => 'Sunrise - Sunset',
          'Wednesday' => 'Sunrise - Sunset'
    services({})
    feedback({})
    access({})
  end

  factory :vba_314c, class: Facilities::VBAFacility do
    unique_id '314c'
    name 'VetSuccss on Campus at Norfolk State University'
    facility_type 'va_benefits_facility'
    classification 'OUTBASED'
    website nil
    lat 36.8476575
    long(-76.26950512)
    address 'mailing' => {},
            'physical' => {
              'zip' => '23504',
              'city' => 'Norfolk',
              'state' => 'VA',
              'address_1' => '700 Park Avenue',
              'address_2' => '',
              'address_3' => nil
            }
    phone 'fax' => '757-823-2078', 'main' => '757-823-8551'
    hours 'Friday' => 'Closed',
          'Monday' => 'Closed',
          'Sunday' => 'Closed',
          'Tuesday' => 'Closed',
          'Saturday' => 'Closed',
          'Thursday' => '7:00AM-4:30PM',
          'Wednesday' => '7:00AM-4:30PM'
    services 'benefits' => {
      'other' => '',
      'standard' => %w[
        ApplyingForBenefits
        EducationAndCareerCounseling
        HomelessAssistance
        TransitionAssistance
        VocationalRehabilitationAndEmploymentAssistance
      ]
    }
    feedback({})
    access({})
  end

  factory :vc_0543V, class: Facilities::VCFacility do
    unique_id '0543V'
    name 'Fort Collins Vet Center'
    facility_type 'vet_center'
    classification nil
    website nil
    lat 40.5528
    long(-105.09)
    address 'mailing' => {},
            'physical' => {
              'zip' => '80526',
              'city' => 'Fort Collins',
              'state' => 'CO',
              'address_1' => '702 West Drake Road',
              'address_2' => 'Building C',
              'address_3' => nil
            }
    phone 'main' => '970-221-5176 x'
    hours 'friday' => '700AM-530PM',
          'monday' => '700AM-530PM',
          'sunday' => '-',
          'tuesday' => '700AM-800PM',
          'saturday' => '800AM-1200PM',
          'thursday' => '700AM-800PM',
          'wednesday' => '700AM-800PM'
    services({})
    feedback({})
    access({})
  end

  # bbox entries for PDX
  factory :vc_0617V, class: Facilities::VCFacility do
    unique_id '0617V'
    name 'Portland Vet Center'
    facility_type 'vet_center'
    classification nil
    website nil
    lat 45.5338
    long(-122.538)
    address 'mailing' => {},
            'physical' => {
              'zip' => '97230',
              'city' => 'Portland',
              'state' => 'OR',
              'address_1' => '1505 NE 122nd Avenue',
              'address_2' => 'Suite 110',
              'address_3' => nil
            }
    phone 'main' => '503-688-5361 x'
    hours 'friday' => '800AM-800PM',
          'monday' => '800AM-730PM',
          'sunday' => '-',
          'tuesday' => '800AM-730PM',
          'saturday' => '-',
          'thursday' => '800AM-630PM',
          'wednesday' => '800AM-630PM'
    services({})
    feedback({})
    access({})
  end
  factory :nca_907, class: Facilities::NCAFacility do
    unique_id '907'
    name 'Willamette National Cemetery'
    facility_type 'va_cemetery'
    classification 'National Cemetery'
    website 'https://www.cem.va.gov/cems/nchp/willamette.asp'
    lat 45.4568385960001
    long(-122.540844696)
    address 'mailing' => {
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
            }
    phone 'fax' => '503-273-5251',
          'main' => '503-273-5250'
    hours 'Friday' => '7:00am - 5:00pm',
          'Monday' => '7:00am - 5:00pm',
          'Sunday' => '7:00am - 5:00pm',
          'Tuesday' => '7:00am - 5:00pm',
          'Saturday' => '7:00am - 5:00pm',
          'Thursday' => '7:00am - 5:00pm',
          'Wednesday' => '7:00am - 5:00pm'
    services({})
    feedback({})
    access({})
  end
  factory :vha_648, class: Facilities::VHAFacility do
    unique_id '648'
    name 'Portland VA Medical Center'
    facility_type 'va_health_facility'
    classification 'VA Medical Center (VAMC)'
    website 'http://www.portland.va.gov/'
    lat 45.4974614500001
    long(-122.68287208)
    address 'mailing' => {},
            'physical' => {
              'zip' => '97239-2964',
              'city' => 'Portland',
              'state' => 'OR',
              'address_1' => '3710 Southwest US Veterans Hospital Road',
              'address_2' => nil,
              'address_3' => nil
            }
    phone 'fax' => '503-273-5319 x',
          'main' => '503-721-1498 x',
          'pharmacy' => '503-273-5183 x',
          'after_hours' => '503-220-8262 x',
          'patient_advocate' => '503-273-5308 x',
          'mental_health_clinic' => '503-273-5187',
          'enrollment_coordinator' => '503-273-5069 x'
    hours 'Friday' => '24/7',
          'Monday' => '24/7',
          'Sunday' => '24/7',
          'Tuesday' => '24/7',
          'Saturday' => '24/7',
          'Thursday' => '24/7',
          'Wednesday' => '24/7'
    services 'health' => [
      { 'sl1' => ['DentalServices'],
        'sl2' => [] },
      { 'sl1' => ['MentalHealthCare'],
        'sl2' => [] },
      { 'sl1' => ['PrimaryCare'],
        'sl2' => [] }
    ],
             'last_updated' => '2018-03-15'
    feedback 'health' => {
      'effective_date' => '2017-08-15',
      'primary_care_urgent' => '0.73',
      'primary_care_routine' => '0.82',
      'specialty_care_urgent' => '0.75',
      'specialty_care_routine' => '0.82'
    }
    access 'health' => {
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
      'opthalmology' => {
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
      'urology_clinic' => {
        'new' => 24.0,
        'established' => 8.0
      },
      'gastroenterology' => {
        'new' => 24.0,
        'established' => 13.0
      }
    }
  end
  factory :vha_648GI, class: Facilities::VHAFacility do
    unique_id '648GI'
    name 'Portland VA Clinic'
    facility_type 'va_health_facility'
    classification 'Primary Care CBOC'
    website nil
    lat 45.52017304
    long(-122.67221794)
    address 'mailing' => {},
            'physical' => {
              'zip' => '97204-3432',
              'city' => 'Portland',
              'state' => 'OR',
              'address_1' => '308 Southwest 1st Avenue',
              'address_2' => 'Lawrence Building',
              'address_3' => 'Suite 155'
            }
    phone 'fax' => '503-808-1900 x',
          'main' => '503-808-1256 x',
          'pharmacy' => '503-273-5183 x',
          'after_hours' => '800-273-8255 x',
          'patient_advocate' => '503-273-5308 x',
          'mental_health_clinic' => '',
          'enrollment_coordinator' => '503-273-5069 x'
    hours 'Friday' => '800AM-430PM',
          'Monday' => '800AM-430PM',
          'Sunday' => '-',
          'Tuesday' => '800AM-430PM',
          'Saturday' => '-',
          'Thursday' => '800AM-430PM',
          'Wednesday' => '800AM-430PM'
    services 'health' => [
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
             'last_updated' => '2018-03-15'
    feedback 'health' => {}
    access 'health' => {
      'primary_care' => {
        'new' => 12.0,
        'established' => 2.0
      },
      'effective_date' => '2018-03-05'
    }
  end
  factory :vba_348, class: Facilities::VBAFacility do
    unique_id '348'
    name 'Portland Regional Benefits Office'
    facility_type 'va_benefits_facility'
    classification 'REGIONAL OFFICE (MAIN BLDG)'
    website 'http://www.benefits.va.gov/portland'
    lat 45.51516229
    long(-122.6755173)
    address 'mailing' => {},
            'physical' => {
              'zip' => '97204',
              'city' => 'Portland',
              'state' => 'OR',
              'address_1' => '100 SW Main Street',
              'address_2' => 'Floor 2',
              'address_3' => nil
            }
    phone 'fax' => '503-412-4733',
          'main' => '1-800-827-1000'
    hours 'Friday' => '8:00AM-4:00PM',
          'Monday' => '8:00AM-4:00PM',
          'Sunday' => 'Closed',
          'Tuesday' => '8:00AM-4:00PM',
          'Saturday' => 'Closed',
          'Thursday' => '8:00AM-4:00PM',
          'Wednesday' => '8:00AM-4:00PM'
    services 'benefits' => {
      'other' => '',
      'standard' => %w[
        ApplyingForBenefits
        DisabilityClaimAssistance
        eBenefitsRegistrationAssistance
        HomelessAssistance
        TransitionAssistance
        UpdatingDirectDepositInformation
        VocationalRehabilitationAndEmploymentAssistance
      ]
    }
    feedback({})
    access({})
  end
  factory :vba_348a, class: Facilities::VBAFacility do
    unique_id '348a'
    name 'Portland Vocational Rehabilitation and Employment Office'
    facility_type 'va_benefits_facility'
    classification 'VOC REHAB AND EMPLOYMENT'
    website nil
    lat 45.51516229
    long(-122.6755173)
    address 'mailing' => {},
            'physical' => {
              'zip' => '97204',
              'city' => 'Portland',
              'state' => 'OR',
              'address_1' => '100 SW Main St',
              'address_2' => 'Floor 2',
              'address_3' => nil
            }
    phone 'fax' => '503-412-4740',
          'main' => '503-412-4577'
    hours 'Friday' => '8:00AM-4:00PM',
          'Monday' => '8:00AM-4:00PM',
          'Sunday' => 'Closed',
          'Tuesday' => '8:00AM-4:00PM',
          'Saturday' => 'Closed',
          'Thursday' => '8:00AM-4:00PM',
          'Wednesday' => '8:00AM-4:00PM'
    services 'benefits' => {
      'other' => "Educational and Vocational Counseling for Servicemembers and Veterans,
      Independent Living assessment and provision of services, personal adjustment counseling,
      referrals for intensive health services at VAMC, referrals to community support services,
      survivors and dependents' assistance, assistance with school issues. ",
      'standard' => %w[
        EducationAndCareerCounseling
        TransitionAssistance
        VocationalRehabilitationAndEmploymentAssistance
      ]
    }
    feedback({})
    access({})
  end
  factory :vba_348d, class: Facilities::VBAFacility do
    unique_id '348d'
    name 'VetSuccess on Campus at Portland State University'
    facility_type 'va_benefits_facility'
    classification 'VETSUCCESS ON CAMPUS'
    website nil
    lat 45.51144272
    long(-122.6844775)
    address 'mailing' => {},
            'physical' => {
              'zip' => '97204',
              'city' => 'Portland',
              'state' => 'OR',
              'address_1' => '724 SW Harrison',
              'address_2' => '',
              'address_3' => nil
            }
    phone 'fax' => '',
          'main' => '503-412-4577'
    hours 'Friday' => '8:00AM-4:30PM',
          'Monday' => '8:00AM-4:30PM',
          'Sunday' => 'Closed',
          'Tuesday' => '8:00AM-4:30PM',
          'Saturday' => 'Closed',
          'Thursday' => '8:00AM-4:30PM',
          'Wednesday' => '8:00AM-4:30PM'
    services 'benefits' => {
      'other' => 'On campus outreach to Veterans, Referrals fro VA health services, adjustment
      counseling, job placement assistance coordination, referrals to campus services, expertise
      to PSU community of Veteran experience, assist with academic counseling.',
      'standard' => %w[
        ApplyingForBenefits
        EducationAndCareerCounseling
        TransitionAssistance
        VocationalRehabilitationAndEmploymentAssistance
      ]
    }
    feedback({})
    access({})
  end
  factory :vba_348e, class: Facilities::VBAFacility do
    unique_id '348e'
    name 'VetSuccess on Campus at Portland Community College Cascade Campus'
    facility_type 'va_benefits_facility'
    classification 'VETSUCCESS ON CAMPUS'
    website nil
    lat 45.56273715
    long(-122.6676496)
    address 'mailing' => {},
            'physical' => {
              'zip' => '97217',
              'city' => 'Portland',
              'state' => 'OR',
              'address_1' => '75 N. Killingsworth St.',
              'address_2' => '',
              'address_3' => nil
            }
    phone 'fax' => '',
          'main' => '503-412-4577'
    hours 'Friday' => '8:00AM-4:30PM',
          'Monday' => '8:00AM-4:30PM',
          'Sunday' => 'Closed',
          'Tuesday' => '8:00AM-4:30PM',
          'Saturday' => 'Closed',
          'Thursday' => '8:00AM-4:30PM',
          'Wednesday' => '8:00AM-4:30PM'
    services 'benefits' => {
      'other' => 'On campus outreach to Veterans, Referrals fro VA health services, adjustment counseling,
      job placement assistance coordination, referrals to campus services, expertise to PCC community of
      Veteran experience, assist with academic counseling.',
      'standard' => %w[
        ApplyingForBenefits
        EducationAndCareerCounseling
        TransitionAssistance
        VocationalRehabilitationAndEmploymentAssistance
      ]
    }
    feedback({})
    access({})
  end
  factory :vba_348h, class: Facilities::VBAFacility do
    unique_id '348h'
    name 'Vancouver Vocational Rehabilitation and Employment Office'
    facility_type   'va_benefits_facility'
    classification 'VOC REHAB AND EMPLOYMENT'
    website nil
    lat 45.6394162600001
    long(-122.6552874)
    address 'mailing' => {},
            'physical' => {
              'zip' => '98661',
              'city' => 'Vancouver',
              'state' => 'WA',
              'address_1' => '1601 E Fourth Pain Blvd',
              'address_2' => 'V3CH31, Bldg 18',
              'address_3' => nil
            }
    phone 'fax' => '360-759-1679',
          'main' => '503-412-4577'
    hours 'Friday' => '8:00AM-4:30PM',
          'Monday' => '8:00AM-4:30PM',
          'Sunday' => 'Closed',
          'Tuesday' => '8:00AM-4:30PM',
          'Saturday' => 'Closed',
          'Thursday' => '8:00AM-4:30PM',
          'Wednesday' => '8:00AM-4:30PM'
    services 'benefits' => {
      'other' => "Educational and Vocational Counseling for Servicemembers and Veterans, Independent
      Living assessment and provision of services, personal adjustment counseling, referrals for intensive
      health services at VAMC, referrals to community support services, survivors and dependents' assistance,
      assistance with school issues. ",
      'standard' => %w[
        EducationAndCareerCounseling
        TransitionAssistance
        VocationalRehabilitationAndEmploymentAssistance
      ]
    }
    feedback({})
    access({})
  end
  # bbox entries for NY nca
  factory :nca_824, class: Facilities::NCAFacility do
    unique_id '824'
    name 'Woodlawn National Cemetery'
    facility_type 'va_cemetery'
    classification 'National Cemetery'
    website 'https://www.cem.va.gov/cems/nchp/woodlawn.asp'
    lat 42.111095628
    long(-76.8265631089999)
    address 'mailing' => {
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
            }
    phone 'fax' => '607-732-1769',
          'main' => '607-732-5411'
    hours 'Friday' => 'Sunrise - Sunset',
          'Monday' => 'Sunrise - Sunset',
          'Sunday' => 'Sunrise - Sunset',
          'Tuesday' => 'Sunrise - Sunset',
          'Saturday' => 'Sunrise - Sunset',
          'Thursday' => 'Sunrise - Sunset',
          'Wednesday' => 'Sunrise - Sunset'
    services({})
    feedback({})
    access({})
  end
  factory :nca_088, class: Facilities::NCAFacility do
    unique_id '088'
    name "Albany Rural Cemetery Soldiers' Lot"
    facility_type 'va_cemetery'
    classification 'Rural'
    website nil
    lat 42.7038448500001
    long(-73.72356501)
    address 'mailing' => {
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
            }
    phone 'fax' => '5184630787',
          'main' => '5184637017'
    hours 'Friday' => 'Sunrise - Sundown',
          'Monday' => 'Sunrise - Sundown',
          'Sunday' => 'Sunrise - Sundown',
          'Tuesday' => 'Sunrise - Sundown',
          'Saturday' => 'Sunrise - Sundown',
          'Thursday' => 'Sunrise - Sundown',
          'Wednesday' => 'Sunrise - Sundown'
    services({})
    feedback({})
    access({})
  end
  factory :nca_808, class: Facilities::NCAFacility do
    unique_id '808'
    name 'Cypress Hills National Cemetery'
    facility_type  'va_cemetery'
    classification 'National Cemetery'
    website 'https://www.cem.va.gov/cems/nchp/cypresshills.asp'
    lat 40.6859544970001
    long(-73.8812331729999)
    address 'mailing' => {
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
            }
    phone 'fax' => '631-694-5422',
          'main' => '631-454-4949'
    hours 'Friday' => '8:00am - 4:30pm',
          'Monday' => '8:00am - 4:30pm',
          'Sunday' => '8:00am - 4:30pm',
          'Tuesday' => '8:00am - 4:30pm',
          'Saturday' => '8:00am - 4:30pm',
          'Thursday' => '8:00am - 4:30pm',
          'Wednesday' => '8:00am - 4:30pm'
    services({})
    feedback({})
    access({})
  end
  factory :nca_803, class: Facilities::NCAFacility do
    unique_id '803'
    name 'Bath National Cemetery'
    facility_type 'va_cemetery'
    classification 'National Cemetery'
    website 'https://www.cem.va.gov/cems/nchp/bath.asp'
    lat 42.347251468
    long(-77.350304205)
    address 'mailing' => {
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
            }
    phone 'fax' => '607-664-4761',
          'main' => '607-664-4806'
    hours 'Friday' => 'Sunrise - Sunset',
          'Monday' => 'Sunrise - Sunset',
          'Sunday' => 'Sunrise - Sunset',
          'Tuesday' => 'Sunrise - Sunset',
          'Saturday' => 'Sunrise - Sunset',
          'Thursday' => 'Sunrise - Sunset',
          'Wednesday' => 'Sunrise - Sunset'
    services({})
    feedback({})
    access({})
  end
  factory :nca_917, class: Facilities::NCAFacility do
    unique_id '917'
    name 'Gerald B.H. Solomon Saratoga National Cemetery'
    facility_type 'va_cemetery'
    classification 'National Cemetery'
    website 'https://www.cem.va.gov/cems/nchp/geraldbhsolomonsaratoga.asp'
    lat 43.026389889
    long(-73.617079936)
    address 'mailing' => {
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
            }
    phone 'fax' => '518-583-6975',
          'main' => '518-581-9128'
    hours 'Friday' => 'Sunrise - Sunset',
          'Monday' => 'Sunrise - Sunset',
          'Sunday' => 'Sunrise - Sunset',
          'Tuesday' => 'Sunrise - Sunset',
          'Saturday' => 'Sunrise - Sunset',
          'Thursday' => 'Sunrise - Sunset',
          'Wednesday' => 'Sunrise - Sunset'
    services({})
    feedback({})
    access({})
  end
  factory :nca_815, class: Facilities::NCAFacility do
    unique_id '815'
    name 'Long Island National Cemetery'
    facility_type 'va_cemetery'
    classification 'National Cemetery'
    website 'https://www.cem.va.gov/cems/nchp/longisland.asp'
    lat 40.750563679
    long(-73.401496373)
    address 'mailing' => {
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
            }
    phone 'fax' => '631-694-5422',
          'main' => '631-454-4949'
    hours 'Friday' => '7:30am - 5:00pm',
          'Monday' => '7:30am - 5:00pm',
          'Sunday' => '7:30am - 5:00pm',
          'Tuesday' => '7:30am - 5:00pm',
          'Saturday' => '7:30am - 5:00pm',
          'Thursday' => '7:30am - 5:00pm',
          'Wednesday' => '7:30am - 5:00pm'
    services({})
    feedback({})
    access({})
  end
  # bbox entries for NY vba
  factory :vba_306, class: Facilities::VBAFacility do
    unique_id '306'
    name 'New York Regional Benefits Office'
    facility_type 'va_benefits_facility'
    classification 'REGIONAL OFFICE (MAIN BLDG)'
    website 'http://www.benefits.va.gov/newyork/'
    lat 40.7283928800001
    long(-74.0062199)
    address 'mailing' => {},
            'physical' =>
      { 'zip' => '10014',
        'city' => 'New York',
        'state' => 'NY',
        'address_1' => '245 W Houston Street',
        'address_2' => '',
        'address_3' => nil }
    phone 'fax' => '212-807-405', 'main' => '1-800-827-1000'
    hours 'Friday' => '8:30AM-4:00PM',
          'Monday' => '8:30AM-4:00PM',
          'Sunday' => 'Closed',
          'Tuesday' => '8:30AM-4:00PM',
          'Saturday' => 'Closed',
          'Thursday' => '8:30AM-4:00PM',
          'Wednesday' => '8:30AM-4:00PM'
    services 'benefits' =>
      { 'other' => '',
        'standard' =>
        %w[ApplyingForBenefits
           DisabilityClaimAssistance
           eBenefitsRegistrationAssistance
           FamilyMemberClaimAssistance
           HomelessAssistance
           UpdatingDirectDepositInformation
           VocationalRehabilitationAndEmploymentAssistance] }
    feedback {}
    access {}
  end
  factory :vba_306a, class: Facilities::VBAFacility do
    unique_id '306a'
    name 'New York Regional Office at Montrose VAMC'
    facility_type 'va_benefits_facility'
    classification 'OUTBASED'
    website nil
    lat 41.24517788
    long(-73.9264304)
    address 'mailing' => {},
            'physical' =>
       { 'zip' => '10548',
         'city' => 'Montrose',
         'state' => 'NY',
         'address_1' => '2094 Albany Post Road',
         'address_2' => 'Bldg. 14, Room 144',
         'address_3' => nil }
    phone 'fax' => '914-788-4861', 'main' => '1-800-827-1000'
    hours 'Friday' => '8:30AM-4:00PM',
          'Monday' => '8:30AM-4:00PM',
          'Sunday' => 'Closed',
          'Tuesday' => '8:30AM-4:00PM',
          'Saturday' => 'Closed',
          'Thursday' => '8:30AM-4:00PM',
          'Wednesday' => '8:30AM-4:00PM'
    services 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[EducationAndCareerCounseling
            VocationalRehabilitationAndEmploymentAssistance] }
    feedback {}
    access {}
  end

  factory :vba_306b, class: Facilities::VBAFacility do
    unique_id '306b'
    name 'New York Regional Office at Albany VAMC Hicksville'
    facility_type 'va_benefits_facility'
    classification 'OUTBASED'
    website nil
    lat 42.65140884
    long(-73.77623285)
    address 'mailing' => {},
            'physical' =>
       { 'zip' => '12208',
         'city' => 'Albany',
         'state' => 'NY',
         'address_1' => '113 Holland Avenue',
         'address_2' => 'Room C308',
         'address_3' => nil }
    phone 'fax' => '518-626-5695', 'main' => '518-626-5692'
    hours 'Friday' => '8:30AM-4:00PM',
          'Monday' => '8:30AM-4:00PM',
          'Sunday' => 'Closed',
          'Tuesday' => '8:30AM-4:00PM',
          'Saturday' => 'Closed',
          'Thursday' => '8:30AM-4:00PM',
          'Wednesday' => '8:30AM-4:00PM'
    services 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[EducationAndCareerCounseling
            VocationalRehabilitationAndEmploymentAssistance] }
    feedback {}
    access {}
  end

  factory :vba_306c, class: Facilities::VBAFacility do
    unique_id '306c'
    name 'New York Regional Office at Hicksville Vet Center'
    facility_type 'va_benefits_facility'
    classification 'OUTBASED'
    website nil
    lat 40.74498866
    long(-73.4993731499999)
    address 'mailing' => {},
            'physical' =>
       { 'zip' => '11801',
         'city' => 'Hicksville',
         'state' => 'NY',
         'address_1' => '970 S Broadway',
         'address_2' => '',
         'address_3' => nil }
    phone 'fax' => '', 'main' => '516-348-0088'
    hours 'Friday' => '8:30AM-4:00PM',
          'Monday' => '8:30AM-4:00PM',
          'Sunday' => 'Closed',
          'Tuesday' => 'Closed',
          'Saturday' => 'Closed',
          'Thursday' => '8:30AM-4:00PM',
          'Wednesday' => 'Closed'
    services 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[EducationAndCareerCounseling
            VocationalRehabilitationAndEmploymentAssistance] }
    feedback {}
    access {}
  end
  factory :vba_306d, class: Facilities::VBAFacility do
    unique_id '306d'
    name 'New York Regional Office IDES at Montrose VAMC'
    facility_type 'va_benefits_facility'
    classification 'IDES/PRE-DISCHARGE/CLAIMS INTAKE SITE'
    website nil
    lat 41.24517788
    long(-73.9264304)
    address 'mailing' => {},
            'physical' =>
       { 'zip' => '10548',
         'city' => 'Montrose',
         'state' => 'NY',
         'address_1' => '2094 Albany Post Road',
         'address_2' => 'Building 14',
         'address_3' => nil }
    phone 'fax' => '914-788-4861', 'main' => '914-737-4400 x3617'
    hours 'Friday' => '7:30AM-4:00PM',
          'Monday' => '7:30AM-4:00PM',
          'Sunday' => 'Closed',
          'Tuesday' => '7:30AM-4:00PM',
          'Saturday' => 'Closed',
          'Thursday' => '7:30AM-4:00PM',
          'Wednesday' => '7:30AM-4:00PM'
    services 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[IntegratedDisabilityEvaluationSystemAssistance
            PreDischargeClaimAssistance] }
    feedback {}
    access {}
  end
  factory :vba_306e, class: Facilities::VBAFacility do
    unique_id '306e'
    name 'New York Regional Office at Albany VAMC'
    facility_type 'va_benefits_facility'
    classification 'OUTBASED'
    website nil
    lat 42.65140884
    long(-73.77623285)
    address 'mailing' => {},
            'physical' =>
       { 'zip' => '12208',
         'city' => 'Albany',
         'state' => 'NY',
         'address_1' => '113 Holland Avenue',
         'address_2' => '',
         'address_3' => nil }
    phone 'fax' => '518-626-5695', 'main' => '518-626-5524'
    hours 'Friday' => '7:30AM-4:00PM',
          'Monday' => '7:30AM-4:00PM',
          'Sunday' => 'Closed',
          'Tuesday' => '7:30AM-4:00PM',
          'Saturday' => 'Closed',
          'Thursday' => '7:30AM-4:00PM',
          'Wednesday' => '7:30AM-4:00PM'
    services 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[ApplyingForBenefits
            BurialClaimAssistance
            DisabilityClaimAssistance
            eBenefitsRegistrationAssistance
            FamilyMemberClaimAssistance
            UpdatingDirectDepositInformation] }
    feedback {}
    access {}
  end
  factory :vba_306f, class: Facilities::VBAFacility do
    unique_id '306f'
    name 'New York Regional Office at Castle Point VAMC'
    facility_type 'va_benefits_facility'
    classification 'OUTBASED'
    website nil
    lat 41.54045655
    long(-73.96222125)
    address 'mailing' => {},
            'physical' =>
       { 'zip' => '12590',
         'city' => 'Wappingers Falls',
         'state' => 'NY',
         'address_1' => '41 Castle Point Rd',
         'address_2' => '',
         'address_3' => nil }
    phone 'fax' => '', 'main' => '845-831-2000 ext 5097'
    hours 'Friday' => 'Closed',
          'Monday' => 'Closed',
          'Sunday' => 'Closed',
          'Tuesday' => '9:00AM-2:00PM',
          'Saturday' => 'Closed',
          'Thursday' => 'Closed',
          'Wednesday' => 'Closed'
    services 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[ApplyingForBenefits
            BurialClaimAssistance
            DisabilityClaimAssistance
            eBenefitsRegistrationAssistance
            FamilyMemberClaimAssistance
            UpdatingDirectDepositInformation] }
    feedback {}
    access {}
  end
  factory :vba_306g, class: Facilities::VBAFacility do
    unique_id '306g'
    name 'New York Regional Office Outbased at Montrose VAMC'
    facility_type 'va_benefits_facility'
    classification 'OUTBASED'
    website nil
    lat 41.24517788
    long(-73.9264304)
    address 'mailing' => {},
            'physical' =>
       { 'zip' => '10548',
         'city' => 'Montrose',
         'state' => 'NY',
         'address_1' => '2094 Albany Post Road',
         'address_2' => 'Building 1, Room 19A',
         'address_3' => nil }
    phone 'fax' => '', 'main' => '914-737-4400 ext 2212'
    hours 'Friday' => 'Closed',
          'Monday' => 'Closed',
          'Sunday' => 'Closed',
          'Tuesday' => '9:00AM-3:00PM',
          'Saturday' => 'Closed',
          'Thursday' => 'Closed',
          'Wednesday' => 'Closed'
    services 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[ApplyingForBenefits
            BurialClaimAssistance
            DisabilityClaimAssistance
            eBenefitsRegistrationAssistance
            FamilyMemberClaimAssistance
            UpdatingDirectDepositInformation] }
    feedback {}
    access {}
  end
  factory :vba_306h, class: Facilities::VBAFacility do
    unique_id '306h'
    name 'New York Regional Office Outbased at Manhattan VAMC, Office 1'
    facility_type 'va_benefits_facility'
    classification 'OUTBASED'
    website nil
    lat 40.73709039
    long(-73.97694726)
    address 'mailing' => {},
            'physical' =>
       { 'zip' => '10010',
         'city' => 'New York',
         'state' => 'NY',
         'address_1' => '423 East 23rd Street',
         'address_2' => '2nd Floor, Room 2207N',
         'address_3' => nil }
    phone 'fax' => '', 'main' => '212-686-7500 ext 3189'
    hours 'Friday' => 'Closed',
          'Monday' => '9:00AM-5:30PM',
          'Sunday' => 'Closed',
          'Tuesday' => 'Closed',
          'Saturday' => 'Closed',
          'Thursday' => '9:00AM-5:30PM',
          'Wednesday' => 'Closed'
    services 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[ApplyingForBenefits
            BurialClaimAssistance
            DisabilityClaimAssistance
            eBenefitsRegistrationAssistance
            FamilyMemberClaimAssistance
            UpdatingDirectDepositInformation] }
    feedback {}
    access {}
  end
  factory :vba_306i, class: Facilities::VBAFacility do
    unique_id '306i'
    name 'New York Regional Office Outbased  at Manhattan VAMC, Office 2'
    facility_type 'va_benefits_facility'
    classification 'OUTBASED'
    website nil
    lat 40.73709039
    long(-73.97694726)
    address 'mailing' => {},
            'physical' =>
       { 'zip' => '10010',
         'city' => 'New York',
         'state' => 'NY',
         'address_1' => '423 East 23rd Street',
         'address_2' => 'Floor 15(s), Room 15108AS',
         'address_3' => nil }
    phone 'fax' => '', 'main' => '212-868-7500'
    hours 'Friday' => 'Closed',
          'Monday' => '8:45AM-4:45PM',
          'Sunday' => 'Closed',
          'Tuesday' => 'Closed',
          'Saturday' => 'Closed',
          'Thursday' => 'Closed',
          'Wednesday' => 'Closed'
    services 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[ApplyingForBenefits
            BurialClaimAssistance
            DisabilityClaimAssistance
            eBenefitsRegistrationAssistance
            FamilyMemberClaimAssistance
            HomelessAssistance
            UpdatingDirectDepositInformation] }
    feedback {}
    access {}
  end
  factory :vba_309, class: Facilities::VBAFacility do
    unique_id '309'
    name 'Newark VA Regional Benefits Office'
    facility_type 'va_benefits_facility'
    classification 'REGIONAL OFFICE (MAIN BLDG)'
    website 'http://www.benefits.va.gov/newark'
    lat 40.7426633600001
    long(-74.17077896)
    address 'mailing' => {},
            'physical' =>
       { 'zip' => '07102',
         'city' => 'Newark',
         'state' => 'NJ',
         'address_1' => '20 Washington Place',
         'address_2' => '',
         'address_3' => nil }
    phone 'fax' => '973-297-3361', 'main' => '973-297-3348'
    hours 'Friday' => '8:30AM-4:30PM',
          'Monday' => '8:30AM-4:30PM',
          'Sunday' => 'Closed',
          'Tuesday' => '8:30AM-4:30PM',
          'Saturday' => 'Closed',
          'Thursday' => '8:30AM-4:30PM',
          'Wednesday' => '8:30AM-4:30PM'
    services 'benefits' =>
       { 'other' => 'Education Counseling, Outreach, Benefits Reviews, ',
         'standard' =>
         %w[ApplyingForBenefits
            BurialClaimAssistance
            DisabilityClaimAssistance
            eBenefitsRegistrationAssistance
            EducationAndCareerCounseling
            EducationClaimAssistance
            FamilyMemberClaimAssistance
            HomelessAssistance
            TransitionAssistance
            UpdatingDirectDepositInformation
            VocationalRehabilitationAndEmploymentAssistance] }
    feedback {}
    access {}
  end
  factory :vba_310e, class: Facilities::VBAFacility do
    unique_id '310e'
    name 'Wilkes Barre VA Medical Center, Vocational Rehabilitation and Employment Services Office'
    facility_type 'va_benefits_facility'
    classification 'VOC REHAB AND EMPLOYMENT'
    website nil
    lat 41.2475496100001
    long(-75.8411354799999)
    address 'mailing' => {},
            'physical' =>
       { 'zip' => '18702',
         'city' => 'Wilkes Barre',
         'state' => 'PA',
         'address_1' => '1123 East End Blvd',
         'address_2' => 'Bldg 35',
         'address_3' => nil }
    phone 'fax' => '570-821-2510', 'main' => '570-821-2501'
    hours 'Friday' => 'By Appointment Only',
          'Monday' => 'By Appointment Only',
          'Sunday' => 'Closed',
          'Tuesday' => 'By Appointment Only',
          'Saturday' => 'Closed',
          'Thursday' => 'By Appointment Only',
          'Wednesday' => 'By Appointment Only'
    services 'benefits' =>
       { 'other' => '',
         'standard' => ['VocationalRehabilitationAndEmploymentAssistance'] }
    feedback {}
    access {}
  end
end
