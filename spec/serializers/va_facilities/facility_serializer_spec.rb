# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VaFacilities::FacilitySerializer, type: :serializer do
  subject { serialize(facility, serializer_class: described_class) }

  let(:facility) { build :vha_648A4 }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes id' do
    expect(data['id']).to eq('vha_648A4')
  end

  it 'includes name' do
    expect(data['attributes']['name']).to eq('Portland VA Medical Center-Vancouver')
  end

  it 'includes facility_type' do
    expect(data['attributes']['facility_type']).to eq('va_health_facility')
  end

  it 'includes classification' do
    expect(data['attributes']['classification']).to eq('VA Medical Center (VAMC)')
  end

  it 'includes website' do
    expect(data['attributes']['website']).to eq('http://www.portland.va.gov/locations/vancouver.asp')
  end

  it 'includes lat and long' do
    expect(data['attributes']['lat']).to eq(45.6394162600001)
    expect(data['attributes']['long']).to eq(-122.65528736)
  end

  it 'includes address' do
    expected_address = {
      'mailing' => {},
      'physical' => {
        'zip' => '98661-3753',
        'city' => 'Vancouver',
        'state' => 'WA',
        'address_1' => '1601 East 4th Plain Boulevard',
        'address_2' => nil,
        'address_3' => nil
      }
    }
    expect(data['attributes']['address']).to eq(expected_address)
  end

  it 'includes phone' do
    expected_phone = {
      'fax' => '360-690-0864',
      'main' => '360-759-1901',
      'pharmacy' => '503-273-5183',
      'after_hours' => '360-696-4061',
      'patient_advocate' => '503-273-5308',
      'mental_health_clinic' => '503-273-5187',
      'enrollment_coordinator' => '503-273-5069'
    }
    expect(data['attributes']['phone']).to eq(expected_phone)
  end

  it 'includes hours' do
    expected_hours = {
      'friday' => '730AM-430PM',
      'monday' => '730AM-430PM',
      'sunday' => '-',
      'tuesday' => '730AM-630PM',
      'saturday' => '800AM-1000AM',
      'thursday' => '730AM-430PM',
      'wednesday' => '730AM-430PM'
    }
    expect(data['attributes']['hours']).to eq(expected_hours)
  end

  it 'includes mobile' do
    expect(data['attributes']['mobile']).to eq(false)
  end

  it 'includes active_status' do
    expect(data['attributes']['active_status']).to eq('A')
  end

  it 'includes visn' do
    expect(data['attributes']['visn']).to eq('20')
  end

  it 'includes satisfaction' do
    expected_satisfaction = {
      'health' => {
        'primary_care_urgent' => 0.8,
        'primary_care_routine' => 0.84
      },
      'effective_date' => '2017-08-15'
    }
    expect(data['attributes']['satisfaction']).to eq(expected_satisfaction)
  end

  it 'includes wait times' do
    expected_wait_times = {
      'health' => [
        { 'service' => 'Audiology', 'new' => 35.0, 'established' => 18.0 },
        { 'service' => 'Optometry', 'new' => 38.0, 'established' => 22.0 },
        { 'service' => 'Dermatology', 'new' => 4.0, 'established' => nil },
        { 'service' => 'Ophthalmology', 'new' => 1.0, 'established' => 4.0 },
        { 'service' => 'PrimaryCare', 'new' => 34.0, 'established' => 5.0 },
        { 'service' => 'MentalHealth', 'new' => 12.0, 'established' => 3.0 }
      ],
      'effective_date' => '2018-02-26'
    }

    expect(data['attributes']['wait_times']).to eq(expected_wait_times)
  end

  it 'includes services' do
    expected_services = {
      'health' => %w[DentalServices MentalHealthCare PrimaryCare],
      'last_updated' => '2018-03-15'
    }
    expect(data['attributes']['services']).to eq(expected_services)
  end
end
