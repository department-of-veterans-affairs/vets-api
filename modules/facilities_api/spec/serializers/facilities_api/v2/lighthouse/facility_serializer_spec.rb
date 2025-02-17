# frozen_string_literal: true

require 'rails_helper'

describe FacilitiesApi::V2::Lighthouse::FacilitySerializer, team: :facilities, type: :serializer do
  subject { described_class.new(facility) }

  let(:facility) { build(:facilities_api_v2_lighthouse_facility) }
  let(:data) { subject.serializable_hash.with_indifferent_access['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes id' do
    expect(data['id']).to eq('vha_648A4')
  end

  it 'includes name' do
    expect(attributes['name']).to eq('Portland VA Medical Center-Vancouver')
  end

  it 'includes facility_type' do
    expect(attributes['facilityType']).to eq('va_health_facility')
  end

  it 'includes classification' do
    expect(attributes['classification']).to eq('VA Medical Center (VAMC)')
  end

  it 'includes website' do
    expect(attributes['website']).to eq('https://www.portland.va.gov/locations/vancouver.asp')
  end

  it 'includes lat and long' do
    expect(attributes['lat']).to be_within(0.05).of(45.6394162600001)
    expect(attributes['long']).to be_within(0.05).of(-122.65528736)
  end

  it 'includes address' do
    expected_address = {
      'physical' => {
        'zip' => '98661-3753',
        'city' => 'Vancouver',
        'state' => 'WA',
        'address1' => '1601 East 4th Plain Boulevard'
      }
    }
    expect(attributes['address']).to eq(expected_address)
  end

  it 'includes phone' do
    expected_phone = {
      'fax' => '360-690-0864',
      'main' => '360-759-1901',
      'pharmacy' => '503-273-5183',
      'afterHours' => '360-696-4061',
      'patientAdvocate' => '503-273-5308',
      'mentalHealthClinic' => '503-273-5187',
      'enrollmentCoordinator' => '503-273-5069'
    }
    expect(attributes['phone']).to eq(expected_phone)
  end

  it 'includes hours' do
    expected_hours = {
      'monday' => '730AM-430PM',
      'tuesday' => '730AM-630PM',
      'wednesday' => '730AM-430PM',
      'thursday' => '730AM-430PM',
      'friday' => '730AM-430PM',
      'saturday' => 'Closed',
      'sunday' => 'Closed'
    }
    expect(attributes['hours']).to eq(expected_hours)
  end

  it 'includes mobile' do
    expect(attributes['mobile']).to be(false)
  end

  it 'includes operating status' do
    expect(attributes['operatingStatus']).to eq({ 'code' => 'NORMAL' })
  end

  it 'includes visn' do
    expect(attributes['visn']).to eq('20')
  end

  it 'includes feedback' do
    expected_satisfaction = {
      'health' => {
        'primaryCareUrgent' => a_kind_of(Float),
        'primaryCareRoutine' => a_kind_of(Float)
      },
      'effectiveDate' => a_kind_of(Date)
    }
    expect(attributes['feedback']).to match(expected_satisfaction)
  end

  it 'includes operational hours special instructions' do
    expected_special_instructions = [
      'More hours are available for some services. To learn more, call our main phone number.',
      'If you need to talk to someone or get advice right away, call the Vet Center anytime at 1-877-WAR-VETS ' \
      '(1-877-927-8387).'
    ]
    expect(attributes['operationalHoursSpecialInstructions']).to eq(expected_special_instructions)
  end

  it 'includes services' do
    expected_services = {
      'health' => [
        {
          'name' => 'Audiology',
          'serviceId' => 'audiology',
          'link' => 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services/audiology'
        },
        {
          'name' => 'Dermatology',
          'serviceId' => 'dermatology',
          'link' => 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services/dermatology'
        },
        {
          'name' => 'Geriatrics',
          'serviceId' => 'geriatrics',
          'link' => 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services/geriatrics'
        },
        {
          'name' => 'Ophthalmology',
          'serviceId' => 'ophthalmology',
          'link' => 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services/ophthalmology'
        },
        {
          'name' => 'Optometry',
          'serviceId' => 'Optometry',
          'link' => 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services/optometry'
        },
        {
          'name' => 'Primary care',
          'serviceId' => 'primaryCare',
          'link' => 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services/primaryCare'
        }
      ],
      'link' => 'https://example.com/services/va_facilities/v1/facilities/vha_648A4/services',
      'lastUpdated' => a_kind_of(Date)
    }
    expect(attributes['services']).to include(expected_services)
  end

  it 'includes tmpCovidOnlineScheduling' do
    expect(attributes['tmpCovidOnlineScheduling']).to be_nil
  end
end
