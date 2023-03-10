# frozen_string_literal: true

require 'rails_helper'

describe FacilitiesApi::V1::Lighthouse::FacilitySerializer, type: :serializer, team: :facilities do
  subject { described_class.new(facility) }

  let(:facility) { build :facilities_api_v1_lighthouse_facility }
  let(:data) { subject.serializable_hash.with_indifferent_access['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes id' do
    expect(data['id']).to eq('vha_648A4')
  end

  it 'includes name' do
    expect(data['attributes']['name']).to eq('Portland VA Medical Center-Vancouver')
  end

  it 'includes facility_type' do
    expect(data['attributes']['facilityType']).to eq('va_health_facility')
  end

  it 'includes classification' do
    expect(data['attributes']['classification']).to eq('VA Medical Center (VAMC)')
  end

  it 'includes website' do
    expect(data['attributes']['website']).to eq('https://www.portland.va.gov/locations/vancouver.asp')
  end

  it 'includes lat and long' do
    expect(data['attributes']['lat']).to be_within(0.05).of(45.6394162600001)
    expect(data['attributes']['long']).to be_within(0.05).of(-122.65528736)
  end

  it 'includes address' do
    expected_address = {
      'mailing' => {},
      'physical' => {
        'zip' => '98661-3753',
        'city' => 'Vancouver',
        'state' => 'WA',
        'address1' => '1601 East 4th Plain Boulevard',
        'address2' => nil,
        'address3' => nil
      }
    }
    expect(data['attributes']['address']).to eq(expected_address)
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
    expect(data['attributes']['phone']).to eq(expected_phone)
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
    expect(data['attributes']['hours']).to eq(expected_hours)
  end

  it 'includes mobile' do
    expect(data['attributes']['mobile']).to eq(false)
  end

  it 'includes active_status' do
    expect(data['attributes']['activeStatus']).to eq('A')
  end

  it 'includes visn' do
    expect(data['attributes']['visn']).to eq('20')
  end

  it 'includes feedback' do
    expected_satisfaction = {
      'health' => {
        'primaryCareUrgent' => a_kind_of(Float),
        'primaryCareRoutine' => a_kind_of(Float)
      },
      'effectiveDate' => a_kind_of(Date)
    }
    expect(data['attributes']['feedback']).to match(expected_satisfaction)
  end

  it 'includes wait times' do
    expected_wait_times = {
      'health' => [
        { 'service' => 'Audiology',        'new' => a_kind_of(Float), 'established' => a_kind_of(Float) },
        { 'service' => 'Dermatology',      'new' => a_kind_of(Float), 'established' => a_kind_of(Float) },
        { 'service' => 'MentalHealthCare', 'new' => a_kind_of(Float), 'established' => a_kind_of(Float) },
        { 'service' => 'Ophthalmology',    'new' => a_kind_of(Float), 'established' => a_kind_of(Float) },
        { 'service' => 'Optometry',        'new' => a_kind_of(Float), 'established' => a_kind_of(Float) },
        { 'service' => 'PrimaryCare',      'new' => a_kind_of(Float), 'established' => a_kind_of(Float) },
        { 'service' => 'SpecialtyCare',    'new' => a_kind_of(Float), 'established' => a_kind_of(Float) }
      ],
      'effectiveDate' => a_kind_of(Date)
    }
    expect(data['attributes']['access']).to include(expected_wait_times)
  end

  it 'includes services' do
    expected_services = {
      'other' => [],
      'health' => %w[
        Audiology DentalServices Dermatology EmergencyCare MentalHealthCare
        Nutrition Ophthalmology Optometry Podiatry PrimaryCare SpecialtyCare
      ]
    }
    expect(data['attributes']['services']).to eq(expected_services)
  end

  it 'includes tmpCovidOnlineScheduling' do
    expect(data['attributes']['tmpCovidOnlineScheduling']).to be_nil
  end
end
