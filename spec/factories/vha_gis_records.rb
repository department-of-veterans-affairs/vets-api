# frozen_string_literal: false
FactoryGirl.define do
  factory :vha_gis_record, class: Hash do
    gis_attrs do
      {
        'FID' => 1049,
        'OBJECTID' => 1736,
        'FacilityDa' => '8-19-2016',
        'Outpatient' => 1_472_428_800_000,
        'StationID' => 538,
        'VisnID' => 20,
        'StationNum' => '648',
        'StationNam' => 'Portland VA Medical Center',
        'CommonStat' => 'Portland',
        'CocClassif' => 'VA Medical Center (VAMC)',
        'CocClass_1' => 'Firm',
        'Building' => ' ',
        'Street' => '3710 Southwest US Veterans Hospital Road',
        'Suite' => ' ',
        'City' => 'Portland',
        'State' => 'OR',
        'Zip' => '97239',
        'Zip4' => '2964',
        'MainPhone' => '503-721-1498 x',
        'MainFax' => '503-273-5319 x',
        'AfterHours' => '503-220-8262 x',
        'PatientAdv' => '503-273-5308 x',
        'Enrollment' => '503-273-5069 x',
        'PharmacyPh' => '503-273-5183 x',
        'Monday' => '24/7',
        'Tuesday' => '24/7',
        'Wednesday' => '24/7',
        'Thursday' => '24/7',
        'Friday' => '24/7',
        'Saturday' => '24/7',
        'Sunday' => '24/7',
        'Latitude' => 45.49746145,
        'Longitude' => -122.68287208,
        'MHClinicPh' => 5_032_735_187,
        'Extension' => 0,
        'First_Inte' => 'http://www.portland.va.gov/'
      }
    end
    geometry do
      {
        'x' => -13_656_996.4607131,
        'y' => 5_700_180.43265912
      }
    end
    initialize_with { { 'attributes' => gis_attrs, 'geometry' => geometry } }
  end
end
