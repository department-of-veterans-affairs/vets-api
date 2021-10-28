# frozen_string_literal: true

FactoryBot.define do
  factory :vba_314c, class: 'Facilities::VBAFacility' do
    unique_id { '314c' }
    name { 'VetSuccss on Campus at Norfolk State University' }
    facility_type { 'va_benefits_facility' }
    classification { 'OUTBASED' }
    website { nil }
    lat { 36.8476575 }
    long { -76.26950512 }
    location { 'POINT(-76.26950512 36.8476575)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '23504',
          'city' => 'Norfolk',
          'state' => 'VA',
          'address_1' => '700 Park Avenue',
          'address_2' => '',
          'address_3' => nil
        } }
    }
    phone { { 'fax' => '757-823-2078', 'main' => '757-823-8551' } }
    hours {
      { 'Friday' => 'Closed',
        'Monday' => 'Closed',
        'Sunday' => 'Closed',
        'Tuesday' => 'Closed',
        'Saturday' => 'Closed',
        'Thursday' => '7:00AM-4:30PM',
        'Wednesday' => '7:00AM-4:30PM' }
    }
    services {
      { 'benefits' => {
        'other' => '',
        'standard' => %w[
          ApplyingForBenefits
          EducationAndCareerCounseling
          HomelessAssistance
          TransitionAssistance
          VocationalRehabilitationAndEmploymentAssistance
        ]
      } }
    }
    feedback { {} }
    access { {} }
  end
  # bbox entries for PDX
  factory :vba_348, class: 'Facilities::VBAFacility' do
    unique_id { '348' }
    name { 'Portland Regional Benefits Office' }
    facility_type { 'va_benefits_facility' }
    classification { 'REGIONAL OFFICE (MAIN BLDG)' }
    website { 'http://www.benefits.va.gov/portland' }
    lat { 45.51516229 }
    long { -122.6755173 }
    location { 'POINT(-122.6755173 45.51516229)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '97204',
          'city' => 'Portland',
          'state' => 'OR',
          'address_1' => '100 SW Main Street',
          'address_2' => 'Floor 2',
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '503-412-4733',
        'main' => '1-800-827-1000' }
    }
    hours {
      { 'Friday' => '8:00AM-4:00PM',
        'Monday' => '8:00AM-4:00PM',
        'Sunday' => 'Closed',
        'Tuesday' => '8:00AM-4:00PM',
        'Saturday' => 'Closed',
        'Thursday' => '8:00AM-4:00PM',
        'Wednesday' => '8:00AM-4:00PM' }
    }
    services {
      { 'benefits' => {
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
      } }
    }
    feedback { {} }
    access { {} }
  end
  factory :vba_348a, class: 'Facilities::VBAFacility' do
    unique_id { '348a' }
    name { 'Portland Vocational Rehabilitation and Employment Office' }
    facility_type { 'va_benefits_facility' }
    classification { 'VOC REHAB AND EMPLOYMENT' }
    website { nil }
    lat { 45.51516229 }
    long { -122.6755173 }
    location { 'POINT(-122.6755173 45.51516229)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '97204',
          'city' => 'Portland',
          'state' => 'OR',
          'address_1' => '100 SW Main St',
          'address_2' => 'Floor 2',
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '503-412-4740',
        'main' => '503-412-4577' }
    }
    hours {
      { 'Friday' => '8:00AM-4:00PM',
        'Monday' => '8:00AM-4:00PM',
        'Sunday' => 'Closed',
        'Tuesday' => '8:00AM-4:00PM',
        'Saturday' => 'Closed',
        'Thursday' => '8:00AM-4:00PM',
        'Wednesday' => '8:00AM-4:00PM' }
    }
    services {
      { 'benefits' => {
        'other' => "Educational and Vocational Counseling for Servicemembers and Veterans,
        Independent Living assessment and provision of services, personal adjustment counseling,
        referrals for intensive health services at VAMC, referrals to community support services,
        survivors and dependents' assistance, assistance with school issues. ",
        'standard' => %w[
          EducationAndCareerCounseling
          TransitionAssistance
          VocationalRehabilitationAndEmploymentAssistance
        ]
      } }
    }
    feedback { {} }
    access { {} }
  end
  factory :vba_348d, class: 'Facilities::VBAFacility' do
    unique_id { '348d' }
    name { 'VetSuccess on Campus at Portland State University' }
    facility_type { 'va_benefits_facility' }
    classification { 'VETSUCCESS ON CAMPUS' }
    website { nil }
    lat { 45.51144272 }
    long { -122.6844775 }
    location { 'POINT(-122.6844775 45.51144272)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '97204',
          'city' => 'Portland',
          'state' => 'OR',
          'address_1' => '724 SW Harrison',
          'address_2' => '',
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '',
        'main' => '503-412-4577' }
    }
    hours {
      { 'Friday' => '8:00AM-4:30PM',
        'Monday' => '8:00AM-4:30PM',
        'Sunday' => 'Closed',
        'Tuesday' => '8:00AM-4:30PM',
        'Saturday' => 'Closed',
        'Thursday' => '8:00AM-4:30PM',
        'Wednesday' => '8:00AM-4:30PM' }
    }
    services {
      { 'benefits' => {
        'other' => 'On campus outreach to Veterans, Referrals fro VA health services, adjustment
        counseling, job placement assistance coordination, referrals to campus services, expertise
        to PSU community of Veteran experience, assist with academic counseling.',
        'standard' => %w[
          ApplyingForBenefits
          EducationAndCareerCounseling
          TransitionAssistance
          VocationalRehabilitationAndEmploymentAssistance
        ]
      } }
    }
    feedback { {} }
    access { {} }
  end
  factory :vba_348e, class: 'Facilities::VBAFacility' do
    unique_id { '348e' }
    name { 'VetSuccess on Campus at Portland Community College Cascade Campus' }
    facility_type { 'va_benefits_facility' }
    classification { 'VETSUCCESS ON CAMPUS' }
    website { nil }
    lat { 45.56273715 }
    long { -122.6676496 }
    location { 'POINT(-122.6676496 45.56273715)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '97217',
          'city' => 'Portland',
          'state' => 'OR',
          'address_1' => '75 N. Killingsworth St.',
          'address_2' => '',
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '',
        'main' => '503-412-4577' }
    }
    hours {
      { 'Friday' => '8:00AM-4:30PM',
        'Monday' => '8:00AM-4:30PM',
        'Sunday' => 'Closed',
        'Tuesday' => '8:00AM-4:30PM',
        'Saturday' => 'Closed',
        'Thursday' => '8:00AM-4:30PM',
        'Wednesday' => '8:00AM-4:30PM' }
    }
    services {
      { 'benefits' => {
        'other' => 'On campus outreach to Veterans, Referrals fro VA health services, adjustment counseling,
        job placement assistance coordination, referrals to campus services, expertise to PCC community of
        Veteran experience, assist with academic counseling.',
        'standard' => %w[
          ApplyingForBenefits
          EducationAndCareerCounseling
          TransitionAssistance
          VocationalRehabilitationAndEmploymentAssistance
        ]
      } }
    }
    feedback { {} }
    access { {} }
  end
  factory :vba_348h, class: 'Facilities::VBAFacility' do
    unique_id { '348h' }
    name { 'Vancouver Vocational Rehabilitation and Employment Office' }
    facility_type { 'va_benefits_facility' }
    classification { 'VOC REHAB AND EMPLOYMENT' }
    website { nil }
    lat { 45.6394162600001 }
    long { -122.6552874 }
    location { 'POINT(-122.6552874 45.6394162600001)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '98661',
          'city' => 'Vancouver',
          'state' => 'WA',
          'address_1' => '1601 E Fourth Pain Blvd',
          'address_2' => 'V3CH31, Bldg 18',
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '360-759-1679',
        'main' => '503-412-4577' }
    }
    hours {
      { 'Friday' => '8:00AM-4:30PM',
        'Monday' => '8:00AM-4:30PM',
        'Sunday' => 'Closed',
        'Tuesday' => '8:00AM-4:30PM',
        'Saturday' => 'Closed',
        'Thursday' => '8:00AM-4:30PM',
        'Wednesday' => '8:00AM-4:30PM' }
    }
    services {
      { 'benefits' => {
        'other' => "Educational and Vocational Counseling for Servicemembers and Veterans, Independent
        Living assessment and provision of services, personal adjustment counseling, referrals for intensive
        health services at VAMC, referrals to community support services, survivors and dependents' assistance,
        assistance with school issues. ",
        'standard' => %w[
          EducationAndCareerCounseling
          TransitionAssistance
          VocationalRehabilitationAndEmploymentAssistance
        ]
      } }
    }
    feedback { {} }
    access { {} }
  end
  # bbox entries for NY vba
  factory :vba_306, class: 'Facilities::VBAFacility' do
    unique_id { '306' }
    name { 'New York Regional Benefits Office' }
    facility_type { 'va_benefits_facility' }
    classification { 'REGIONAL OFFICE (MAIN BLDG)' }
    website { 'http://www.benefits.va.gov/newyork/' }
    lat { 40.7283928800001 }
    long { -74.0062199 }
    location { 'POINT(-74.0062199 40.7283928800001)' }
    address {
      { 'mailing' => {},
        'physical' =>
      { 'zip' => '10014',
        'city' => 'New York',
        'state' => 'NY',
        'address_1' => '245 W Houston Street',
        'address_2' => '',
        'address_3' => nil } }
    }
    phone { { 'fax' => '212-807-405', 'main' => '1-800-827-1000' } }
    hours {
      { 'Friday' => '8:30AM-4:00PM',
        'Monday' => '8:30AM-4:00PM',
        'Sunday' => 'Closed',
        'Tuesday' => '8:30AM-4:00PM',
        'Saturday' => 'Closed',
        'Thursday' => '8:30AM-4:00PM',
        'Wednesday' => '8:30AM-4:00PM' }
    }
    services {
      { 'benefits' =>
      { 'other' => '',
        'standard' =>
        %w[ApplyingForBenefits
           DisabilityClaimAssistance
           eBenefitsRegistrationAssistance
           FamilyMemberClaimAssistance
           HomelessAssistance
           UpdatingDirectDepositInformation
           VocationalRehabilitationAndEmploymentAssistance] } }
    }
    feedback {}
    access {}
  end
  factory :vba_306a, class: 'Facilities::VBAFacility' do
    unique_id { '306a' }
    name { 'New York Regional Office at Montrose VAMC' }
    facility_type { 'va_benefits_facility' }
    classification { 'OUTBASED' }
    website { nil }
    lat { 41.24517788 }
    long { -73.9264304 }
    location { 'POINT(-73.9264304 41.24517788)' }
    address {
      { 'mailing' => {},
        'physical' =>
       { 'zip' => '10548',
         'city' => 'Montrose',
         'state' => 'NY',
         'address_1' => '2094 Albany Post Road',
         'address_2' => 'Bldg. 14, Room 144',
         'address_3' => nil } }
    }
    phone { { 'fax' => '914-788-4861', 'main' => '1-800-827-1000' } }
    hours {
      { 'Friday' => '8:30AM-4:00PM',
        'Monday' => '8:30AM-4:00PM',
        'Sunday' => 'Closed',
        'Tuesday' => '8:30AM-4:00PM',
        'Saturday' => 'Closed',
        'Thursday' => '8:30AM-4:00PM',
        'Wednesday' => '8:30AM-4:00PM' }
    }
    services {
      { 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[EducationAndCareerCounseling
            VocationalRehabilitationAndEmploymentAssistance] } }
    }
    feedback {}
    access {}
  end

  factory :vba_306b, class: 'Facilities::VBAFacility' do
    unique_id { '306b' }
    name { 'New York Regional Office at Albany VAMC Hicksville' }
    facility_type { 'va_benefits_facility' }
    classification { 'OUTBASED' }
    website { nil }
    lat { 42.65140884 }
    long { -73.77623285 }
    location { 'POINT(-73.77623285 42.65140884)' }
    address {
      { 'mailing' => {},
        'physical' =>
       { 'zip' => '12208',
         'city' => 'Albany',
         'state' => 'NY',
         'address_1' => '113 Holland Avenue',
         'address_2' => 'Room C308',
         'address_3' => nil } }
    }
    phone { { 'fax' => '518-626-5695', 'main' => '518-626-5692' } }
    hours {
      { 'Friday' => '8:30AM-4:00PM',
        'Monday' => '8:30AM-4:00PM',
        'Sunday' => 'Closed',
        'Tuesday' => '8:30AM-4:00PM',
        'Saturday' => 'Closed',
        'Thursday' => '8:30AM-4:00PM',
        'Wednesday' => '8:30AM-4:00PM' }
    }
    services {
      { 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[EducationAndCareerCounseling
            VocationalRehabilitationAndEmploymentAssistance] } }
    }
    feedback {}
    access {}
  end

  factory :vba_306c, class: 'Facilities::VBAFacility' do
    unique_id { '306c' }
    name { 'New York Regional Office at Hicksville Vet Center' }
    facility_type { 'va_benefits_facility' }
    classification { 'OUTBASED' }
    website { nil }
    lat { 40.74498866 }
    long { -73.4993731499999 }
    location { 'POINT(-73.4993731499999 40.74498866)' }
    address {
      { 'mailing' => {},
        'physical' =>
       { 'zip' => '11801',
         'city' => 'Hicksville',
         'state' => 'NY',
         'address_1' => '970 S Broadway',
         'address_2' => '',
         'address_3' => nil } }
    }
    phone { { 'fax' => '', 'main' => '516-348-0088' } }
    hours {
      { 'Friday' => '8:30AM-4:00PM',
        'Monday' => '8:30AM-4:00PM',
        'Sunday' => 'Closed',
        'Tuesday' => 'Closed',
        'Saturday' => 'Closed',
        'Thursday' => '8:30AM-4:00PM',
        'Wednesday' => 'Closed' }
    }
    services {
      { 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[EducationAndCareerCounseling
            VocationalRehabilitationAndEmploymentAssistance] } }
    }
    feedback {}
    access {}
  end
  factory :vba_306d, class: 'Facilities::VBAFacility' do
    unique_id { '306d' }
    name { 'New York Regional Office IDES at Montrose VAMC' }
    facility_type { 'va_benefits_facility' }
    classification { 'IDES/PRE-DISCHARGE/CLAIMS INTAKE SITE' }
    website { nil }
    lat { 41.24517788 }
    long { -73.9264304 }
    location { 'POINT(-73.9264304 41.24517788)' }
    address {
      { 'mailing' => {},
        'physical' =>
       { 'zip' => '10548',
         'city' => 'Montrose',
         'state' => 'NY',
         'address_1' => '2094 Albany Post Road',
         'address_2' => 'Building 14',
         'address_3' => nil } }
    }
    phone { { 'fax' => '914-788-4861', 'main' => '914-737-4400 x3617' } }
    hours {
      { 'Friday' => '7:30AM-4:00PM',
        'Monday' => '7:30AM-4:00PM',
        'Sunday' => 'Closed',
        'Tuesday' => '7:30AM-4:00PM',
        'Saturday' => 'Closed',
        'Thursday' => '7:30AM-4:00PM',
        'Wednesday' => '7:30AM-4:00PM' }
    }
    services {
      { 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[IntegratedDisabilityEvaluationSystemAssistance
            PreDischargeClaimAssistance] } }
    }
    feedback {}
    access {}
  end
  factory :vba_306e, class: 'Facilities::VBAFacility' do
    unique_id { '306e' }
    name { 'New York Regional Office at Albany VAMC' }
    facility_type { 'va_benefits_facility' }
    classification { 'OUTBASED' }
    website { nil }
    lat { 42.65140884 }
    long { -73.77623285 }
    location { 'POINT(-73.77623285 42.65140884)' }
    address {
      { 'mailing' => {},
        'physical' =>
       { 'zip' => '12208',
         'city' => 'Albany',
         'state' => 'NY',
         'address_1' => '113 Holland Avenue',
         'address_2' => '',
         'address_3' => nil } }
    }
    phone { { 'fax' => '518-626-5695', 'main' => '518-626-5524' } }
    hours {
      { 'Friday' => '7:30AM-4:00PM',
        'Monday' => '7:30AM-4:00PM',
        'Sunday' => 'Closed',
        'Tuesday' => '7:30AM-4:00PM',
        'Saturday' => 'Closed',
        'Thursday' => '7:30AM-4:00PM',
        'Wednesday' => '7:30AM-4:00PM' }
    }
    services {
      { 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[ApplyingForBenefits
            BurialClaimAssistance
            DisabilityClaimAssistance
            eBenefitsRegistrationAssistance
            FamilyMemberClaimAssistance
            UpdatingDirectDepositInformation] } }
    }
    feedback {}
    access {}
  end
  factory :vba_306f, class: 'Facilities::VBAFacility' do
    unique_id { '306f' }
    name { 'New York Regional Office at Castle Point VAMC' }
    facility_type { 'va_benefits_facility' }
    classification { 'OUTBASED' }
    website { nil }
    lat { 41.54045655 }
    long { -73.96222125 }
    location { 'POINT(-73.96222125 41.54045655)' }
    address {
      { 'mailing' => {},
        'physical' =>
       { 'zip' => '12590',
         'city' => 'Wappingers Falls',
         'state' => 'NY',
         'address_1' => '41 Castle Point Rd',
         'address_2' => '',
         'address_3' => nil } }
    }
    phone { { 'fax' => '', 'main' => '845-831-2000 ext 5097' } }
    hours {
      { 'Friday' => 'Closed',
        'Monday' => 'Closed',
        'Sunday' => 'Closed',
        'Tuesday' => '9:00AM-2:00PM',
        'Saturday' => 'Closed',
        'Thursday' => 'Closed',
        'Wednesday' => 'Closed' }
    }
    services {
      { 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[ApplyingForBenefits
            BurialClaimAssistance
            DisabilityClaimAssistance
            eBenefitsRegistrationAssistance
            FamilyMemberClaimAssistance
            UpdatingDirectDepositInformation] } }
    }
    feedback {}
    access {}
  end
  factory :vba_306g, class: 'Facilities::VBAFacility' do
    unique_id { '306g' }
    name { 'New York Regional Office Outbased at Montrose VAMC' }
    facility_type { 'va_benefits_facility' }
    classification { 'OUTBASED' }
    website { nil }
    lat { 41.24517788 }
    long { -73.9264304 }
    location { 'POINT(-73.9264304 41.24517788)' }
    address {
      { 'mailing' => {},
        'physical' =>
       { 'zip' => '10548',
         'city' => 'Montrose',
         'state' => 'NY',
         'address_1' => '2094 Albany Post Road',
         'address_2' => 'Building 1, Room 19A',
         'address_3' => nil } }
    }
    phone { { 'fax' => '', 'main' => '914-737-4400 ext 2212' } }
    hours {
      { 'Friday' => 'Closed',
        'Monday' => 'Closed',
        'Sunday' => 'Closed',
        'Tuesday' => '9:00AM-3:00PM',
        'Saturday' => 'Closed',
        'Thursday' => 'Closed',
        'Wednesday' => 'Closed' }
    }
    services {
      { 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[ApplyingForBenefits
            BurialClaimAssistance
            DisabilityClaimAssistance
            eBenefitsRegistrationAssistance
            FamilyMemberClaimAssistance
            UpdatingDirectDepositInformation] } }
    }
    feedback {}
    access {}
  end
  factory :vba_306h, class: 'Facilities::VBAFacility' do
    unique_id { '306h' }
    name { 'New York Regional Office Outbased at Manhattan VAMC, Office 1' }
    facility_type { 'va_benefits_facility' }
    classification { 'OUTBASED' }
    website { nil }
    lat { 40.73709039 }
    long { -73.97694726 }
    location { 'POINT(-73.97694726 40.73709039)' }
    address {
      { 'mailing' => {},
        'physical' =>
       { 'zip' => '10010',
         'city' => 'New York',
         'state' => 'NY',
         'address_1' => '423 East 23rd Street',
         'address_2' => '2nd Floor, Room 2207N',
         'address_3' => nil } }
    }
    phone { { 'fax' => '', 'main' => '212-686-7500 ext 3189' } }
    hours {
      { 'Friday' => 'Closed',
        'Monday' => '9:00AM-5:30PM',
        'Sunday' => 'Closed',
        'Tuesday' => 'Closed',
        'Saturday' => 'Closed',
        'Thursday' => '9:00AM-5:30PM',
        'Wednesday' => 'Closed' }
    }
    services {
      { 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[ApplyingForBenefits
            BurialClaimAssistance
            DisabilityClaimAssistance
            eBenefitsRegistrationAssistance
            FamilyMemberClaimAssistance
            UpdatingDirectDepositInformation] } }
    }
    feedback {}
    access {}
  end
  factory :vba_306i, class: 'Facilities::VBAFacility' do
    unique_id { '306i' }
    name { 'New York Regional Office Outbased  at Manhattan VAMC, Office 2' }
    facility_type { 'va_benefits_facility' }
    classification { 'OUTBASED' }
    website { nil }
    lat { 40.73709039 }
    long { -73.97694726 }
    location { 'POINT(-73.97694726 40.73709039)' }
    address {
      { 'mailing' => {},
        'physical' =>
       { 'zip' => '10010',
         'city' => 'New York',
         'state' => 'NY',
         'address_1' => '423 East 23rd Street',
         'address_2' => 'Floor 15(s), Room 15108AS',
         'address_3' => nil } }
    }
    phone { { 'fax' => '', 'main' => '212-868-7500' } }
    hours {
      { 'Friday' => 'Closed',
        'Monday' => '8:45AM-4:45PM',
        'Sunday' => 'Closed',
        'Tuesday' => 'Closed',
        'Saturday' => 'Closed',
        'Thursday' => 'Closed',
        'Wednesday' => 'Closed' }
    }
    services {
      { 'benefits' =>
       { 'other' => '',
         'standard' =>
         %w[ApplyingForBenefits
            BurialClaimAssistance
            DisabilityClaimAssistance
            eBenefitsRegistrationAssistance
            FamilyMemberClaimAssistance
            HomelessAssistance
            UpdatingDirectDepositInformation] } }
    }
    feedback {}
    access {}
  end
  factory :vba_309, class: 'Facilities::VBAFacility' do
    unique_id { '309' }
    name { 'Newark VA Regional Benefits Office' }
    facility_type { 'va_benefits_facility' }
    classification { 'REGIONAL OFFICE (MAIN BLDG)' }
    website { 'http://www.benefits.va.gov/newark' }
    lat { 40.7426633600001 }
    long { -74.17077896 }
    location { 'POINT(-74.17077896 40.7426633600001)' }
    address {
      { 'mailing' => {},
        'physical' =>
       { 'zip' => '07102',
         'city' => 'Newark',
         'state' => 'NJ',
         'address_1' => '20 Washington Place',
         'address_2' => '',
         'address_3' => nil } }
    }
    phone { { 'fax' => '973-297-3361', 'main' => '973-297-3348' } }
    hours {
      { 'Friday' => '8:30AM-4:30PM',
        'Monday' => '8:30AM-4:30PM',
        'Sunday' => 'Closed',
        'Tuesday' => '8:30AM-4:30PM',
        'Saturday' => 'Closed',
        'Thursday' => '8:30AM-4:30PM',
        'Wednesday' => '8:30AM-4:30PM' }
    }
    services {
      { 'benefits' =>
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
            VocationalRehabilitationAndEmploymentAssistance] } }
    }
    feedback {}
    access {}
  end
  factory :vba_310e, class: 'Facilities::VBAFacility' do
    unique_id { '310e' }
    name { 'Wilkes Barre VA Medical Center, Vocational Rehabilitation and Employment Services Office' }
    facility_type { 'va_benefits_facility' }
    classification { 'VOC REHAB AND EMPLOYMENT' }
    website { nil }
    lat { 41.2475496100001 }
    long { -75.8411354799999 }
    location { 'POINT(-75.8411354799999 41.2475496100001)' }
    address {
      { 'mailing' => {},
        'physical' =>
       { 'zip' => '18702',
         'city' => 'Wilkes Barre',
         'state' => 'PA',
         'address_1' => '1123 East End Blvd',
         'address_2' => 'Bldg 35',
         'address_3' => nil } }
    }
    phone { { 'fax' => '570-821-2510', 'main' => '570-821-2501' } }
    hours {
      { 'Friday' => 'By Appointment Only',
        'Monday' => 'By Appointment Only',
        'Sunday' => 'Closed',
        'Tuesday' => 'By Appointment Only',
        'Saturday' => 'Closed',
        'Thursday' => 'By Appointment Only',
        'Wednesday' => 'By Appointment Only' }
    }
    services {
      { 'benefits' =>
       { 'other' => '',
         'standard' => ['VocationalRehabilitationAndEmploymentAssistance'] } }
    }
    feedback {}
    access {}
  end
  factory :generic_vba, class: 'Facilities::VBAFacility' do
    sequence :unique_id, &:to_s
    name { 'Generic Benefits Office' }
    facility_type { 'va_benefits_facility' }
    classification { 'REGIONAL OFFICE (MAIN BLDG)' }
    website { 'http://www.benefits.va.gov/generic' }
    lat { 45.51516229 }
    long { -122.6755173 }
    location { 'POINT(-122.6755173 45.51516229)' }
    address {
      { 'mailing' => {},
        'physical' => {
          'zip' => '97204',
          'city' => 'Portland',
          'state' => 'OR',
          'address_1' => '100 Generic Street',
          'address_2' => '',
          'address_3' => nil
        } }
    }
    phone {
      { 'fax' => '555-555-5555',
        'main' => '1-800-555-5555' }
    }
    hours {
      { 'Friday' => '8:00AM-4:00PM',
        'Monday' => '8:00AM-4:00PM',
        'Sunday' => 'Closed',
        'Tuesday' => '8:00AM-4:00PM',
        'Saturday' => 'Closed',
        'Thursday' => '8:00AM-4:00PM',
        'Wednesday' => '8:00AM-4:00PM' }
    }
    services {
      { 'benefits' => {
        'other' => '',
        'standard' => ['ApplyingForBenefits']
      } }
    }
    feedback { {} }
    access { {} }
  end
end
