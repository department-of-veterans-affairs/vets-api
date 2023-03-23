# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BaseFacility, type: :model do
  let(:nca_facility) { Facilities::NCAFacility.create(attrs) }
  let(:vba_facility) { Facilities::VBAFacility.create(attrs) }
  let(:vc_facility) { Facilities::VCFacility.create(attrs) }
  let(:vha_facility) { Facilities::VHAFacility.create(attrs) }

  describe 'VCFacility' do
    let(:attrs) do
      { 'unique_id' => '0543V',
        'name' => 'Fort Collins Vet Center',
        'classification' => nil,
        'website' => nil,
        'lat' => 40.5528,
        'long' => -105.09,
        'address' =>
          { 'mailing' => {},
            'physical' =>
            { 'zip' => '80526',
              'city' => 'Fort Collins',
              'state' => 'CO',
              'address_1' => '702 West Drake Road',
              'address_2' => 'Building C',
              'address_3' => nil } },
        'phone' => { 'main' => '970-221-5176 x' },
        'hours' =>
          { 'friday' => '700AM-530PM',
            'monday' => '700AM-530PM',
            'sunday' => '-',
            'tuesday' => '700AM-800PM',
            'saturday' => '800AM-1200PM',
            'thursday' => '700AM-800PM',
            'wednesday' => '700AM-800PM' },
        'services' => {},
        'feedback' => {},
        'access' => {} }
    end

    it 'saves and retrieve all attributes and they should match the original object' do
      expect(vc_facility.facility_type).to eq('vet_center')
      attrs.each_key { |k| expect(vc_facility[k]).to eq attrs[k] }
      point = vc_facility.location.factory.point attrs['long'], attrs['lat']
      expect(vc_facility.location).to eq(point)
    end
  end

  describe 'VHAFacility' do
    let(:attrs) do
      { 'unique_id' => '648A4',
        'name' => 'Portland VA Medical Center-Vancouver',
        'classification' => 'VA Medical Center (VAMC)',
        'website' => 'http://www.portland.va.gov/locations/vancouver.asp',
        'lat' => 45.6394162600001,
        'long' => -122.65528736,
        'address' =>
          { 'mailing' => {},
            'physical' =>
            { 'zip' => '98661-3753',
              'city' => 'Vancouver',
              'state' => 'WA',
              'address_1' => '1601 East 4th Plain Boulevard',
              'address_2' => nil,
              'address_3' => nil } },
        'phone' =>
          { 'fax' => '360-690-0864 x',
            'main' => '360-759-1901 x',
            'pharmacy' => '503-273-5183 x',
            'after_hours' => '360-696-4061 x',
            'patient_advocate' => '503-273-5308 x',
            'mental_health_clinic' => '503-273-5187',
            'enrollment_coordinator' => '503-273-5069 x' },
        'hours' =>
          { 'Friday' => '730AM-430PM',
            'Monday' => '730AM-430PM',
            'Sunday' => '-',
            'Tuesday' => '730AM-630PM',
            'Saturday' => '800AM-1000AM',
            'Thursday' => '730AM-430PM',
            'Wednesday' => '730AM-430PM' },
        'services' =>
          { 'health' =>
            [{ 'sl1' => ['DentalServices'], 'sl2' => [] },
             { 'sl1' => ['MentalHealthCare'], 'sl2' => [] },
             { 'sl1' => ['PrimaryCare'], 'sl2' => [] }],
            'last_updated' => '2018-03-15' },
        'feedback' =>
          { 'health' =>
            { 'effective_date' => '2017-08-15',
              'primary_care_urgent' => '0.8',
              'primary_care_routine' => '0.84' } },
        'access' =>
          { 'health' =>
            { 'audiology' => { 'new' => 35.0, 'established' => 18.0 },
              'optometry' => { 'new' => 38.0, 'established' => 22.0 },
              'dermatology' => { 'new' => 4.0, 'established' => nil },
              'ophthalmology' => { 'new' => 1.0, 'established' => 4.0 },
              'primary_care' => { 'new' => 34.0, 'established' => 5.0 },
              'mental_health' => { 'new' => 12.0, 'established' => 3.0 },
              'effective_date' => '2018-02-26' } } }
    end

    it 'saves and retrieve all attributes and they should match the original object' do
      expect(vha_facility.facility_type).to eq('va_health_facility')
      attrs.each_key { |k| expect(vha_facility[k]).to eq attrs[k] }
      point = vha_facility.location.factory.point attrs['long'], attrs['lat']
      expect(vha_facility.location).to eq(point)
    end
  end

  describe 'VBAFacility' do
    let(:attrs) do
      { 'unique_id' => '314c',
        'name' => 'VetSuccss on Campus at Norfolk State University',
        'classification' => 'OUTBASED',
        'website' => nil,
        'lat' => 36.8476575,
        'long' => -76.26950512,
        'address' =>
          { 'mailing' => {},
            'physical' =>
            { 'zip' => '23504',
              'city' => 'Norfolk',
              'state' => 'VA',
              'address_1' => '700 Park Avenue',
              'address_2' => '',
              'address_3' => nil } },
        'phone' => { 'fax' => '757-823-2078', 'main' => '757-823-8551' },
        'hours' =>
          { 'Friday' => 'Closed',
            'Monday' => 'Closed',
            'Sunday' => 'Closed',
            'Tuesday' => 'Closed',
            'Saturday' => 'Closed',
            'Thursday' => '7:00AM-4:30PM',
            'Wednesday' => '7:00AM-4:30PM' },
        'services' =>
          { 'benefits' =>
            { 'other' => '',
              'standard' =>
              %w[ApplyingForBenefits
                 EducationAndCareerCounseling
                 HomelessAssistance
                 TransitionAssistance
                 VocationalRehabilitationAndEmploymentAssistance] } },
        'feedback' => {},
        'access' => {} }
    end

    it 'saves and retrieve all attributes and they should match the original object' do
      expect(vba_facility.facility_type).to eq('va_benefits_facility')
      attrs.each_key { |k| expect(vba_facility[k]).to eq attrs[k] }
      point = vba_facility.location.factory.point attrs['long'], attrs['lat']
      expect(vba_facility.location).to eq(point)
    end
  end

  describe 'NCAFacility' do
    let(:attrs) do
      { 'unique_id' => '888',
        'name' => 'Fort Logan National Cemetery',
        'classification' => 'National Cemetery',
        'website' => 'https://www.cem.va.gov/cems/nchp/ftlogan.asp',
        'lat' => 39.6455740260001,
        'long' => -105.052859396,
        'address' => {
          'mailing' => { 'zip' => '80236', 'city' => 'Denver', 'state' => 'CO',
                         'address_1' => '4400 W Kenyon Ave', 'address_2' => nil,
                         'address_3' => nil },
          'physical' => { 'zip' => '80236', 'city' => 'Denver', 'state' => 'CO',
                          'address_1' => '4400 W Kenyon Ave', 'address_2' => nil,
                          'address_3' => nil }
        },
        'phone' => { 'fax' => '303-781-9378', 'main' => '303-761-0117' },
        'hours' => { 'Friday' => 'Sunrise - Sunset', 'Monday' => 'Sunrise - Sunset',
                     'Sunday' => 'Sunrise - Sunset', 'Tuesday' => 'Sunrise - Sunset',
                     'Saturday' => 'Sunrise - Sunset', 'Thursday' => 'Sunrise - Sunset',
                     'Wednesday' => 'Sunrise - Sunset' },
        'services' => {},
        'feedback' => {},
        'access' => {} }
    end

    it 'saves and retrieve all attributes and they should match the original object' do
      expect(nca_facility.facility_type).to eq('va_cemetery')
      attrs.each_key { |k| expect(nca_facility[k]).to eq attrs[k] }
      point = nca_facility.location.factory.point attrs['long'], attrs['lat']
      expect(nca_facility.location).to eq(point)
    end
  end

  describe '#find_facility_by_id' do
    before { create :vha_648A4 }

    it 'finds facility by id' do
      expect(BaseFacility.find_facility_by_id('vha_648A4').id).to eq('648A4')
    end

    it 'has hours that are sorted by day' do
      expect(BaseFacility.find_facility_by_id('vha_648A4').hours.keys).to eq(DateTime::DAYNAMES.rotate)
    end
  end

  it 'returns an empty relation if given more than one distance query param' do
    bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
    params = { state: 'FL', bbox: }
    facilities = BaseFacility.query(params)
    assert facilities.empty?
  end
end
