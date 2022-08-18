# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::VAOSV2Appointments, aggregate_failures: true do
  let(:appointment_fixtures) do
    File.read(Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'VAOS_v2_appointments.json'))
  end

  let(:adapted_appointments) { subject.parse(JSON.parse(appointment_fixtures, symbolize_names: true)) }

  it 'returns a list of appointments at the expected size' do
    expect(adapted_appointments.size).to eq(6)
  end

  context 'with a cancelled VA appointment' do
    let(:cancelled_va) { adapted_appointments[0] }

    it 'has expected fields' do
      expect(cancelled_va[:status_detail]).to eq('CANCELLED BY PATIENT')
      expect(cancelled_va[:status]).to eq('CANCELLED')
      expect(cancelled_va[:appointment_type]).to eq('VA')
      expect(cancelled_va.as_json).to eq({ 'id' => '121133',
                                           'appointment_type' => 'VA',
                                           'cancel_id' => nil,
                                           'comment' => 'This is a free form comment',
                                           'facility_id' => '442',
                                           'sta6aid' => '442',
                                           'healthcare_provider' => nil,
                                           'healthcare_service' => 'Friendly Name Optometry',
                                           'location' => {
                                             'id' => '442',
                                             'name' => 'Cheyenne VA Medical Center',
                                             'address' => {
                                               'street' => '2360 East Pershing Boulevard',
                                               'city' => 'Cheyenne',
                                               'state' => 'WY',
                                               'zip_code' => '82001-5356'
                                             },
                                             'lat' => 41.148026,
                                             'long' => -104.786255,
                                             'phone' => {
                                               'area_code' => '307',
                                               'number' => '778-7550',
                                               'extension' => nil
                                             },
                                             'url' => nil,
                                             'code' => nil
                                           },
                                           'minutes_duration' => 30,
                                           'phone_only' => false,
                                           'start_date_local' => '2022-08-27T09:45:00.000-06:00',
                                           'start_date_utc' => '2022-08-27T15:45:00.000+00:00',
                                           'status' => 'CANCELLED',
                                           'status_detail' => 'CANCELLED BY PATIENT',
                                           'time_zone' => 'America/Denver',
                                           'vetext_id' => nil,
                                           'reason' => nil,
                                           'is_covid_vaccine' => false,
                                           'is_pending' => false,
                                           'proposed_times' => nil,
                                           'type_of_care' => nil,
                                           'patient_phone_number' => nil,
                                           'patient_email' => nil,
                                           'best_time_to_call' => nil,
                                           'friendly_location_name' => nil })
    end
  end

  context 'with a booked VA appointment' do
    let(:booked_va) { adapted_appointments[1] }

    it 'has expected fields' do
      expect(booked_va[:status]).to eq('BOOKED')
      expect(booked_va[:appointment_type]).to eq('VA')
      expect(booked_va.as_json).to eq({
                                        'id' => '121133',
                                        'appointment_type' => 'VA',
                                        'cancel_id' => nil,
                                        'comment' => nil,
                                        'facility_id' => '442',
                                        'sta6aid' => '442',
                                        'healthcare_provider' => nil,
                                        'healthcare_service' => 'Friendly Name Optometry',
                                        'location' => {
                                          'id' => '442',
                                          'name' => 'Cheyenne VA Medical Center',
                                          'address' => {
                                            'street' => '2360 East Pershing Boulevard',
                                            'city' => 'Cheyenne',
                                            'state' => 'WY',
                                            'zip_code' => '82001-5356'
                                          },
                                          'lat' => 41.148026,
                                          'long' => -104.786255,
                                          'phone' => {
                                            'area_code' => '307',
                                            'number' => '778-7550',
                                            'extension' => nil
                                          },
                                          'url' => nil,
                                          'code' => nil
                                        },
                                        'minutes_duration' => 30,
                                        'phone_only' => false,
                                        'start_date_local' => '2018-03-07T08:00:00.000-07:00',
                                        'start_date_utc' => '2018-03-07T15:00:00.000+00:00',
                                        'status' => 'BOOKED',
                                        'status_detail' => nil,
                                        'time_zone' => 'America/Denver',
                                        'vetext_id' => nil,
                                        'reason' => nil,
                                        'is_covid_vaccine' => false,
                                        'is_pending' => false,
                                        'proposed_times' => nil,
                                        'type_of_care' => nil,
                                        'patient_phone_number' => nil,
                                        'patient_email' => nil,
                                        'best_time_to_call' => nil,
                                        'friendly_location_name' => nil
                                      })
    end
  end

  context 'with a booked CC appointment' do
    let(:booked_cc) { adapted_appointments[2] }

    it 'has expected fields' do
      expect(booked_cc[:status]).to eq('BOOKED')
      expect(booked_cc[:appointment_type]).to eq('COMMUNITY_CARE')
      expect(booked_cc[:healthcare_service]).to eq('CC practice name')
      expect(booked_cc[:location][:name]).to eq('CC practice name')
      expect(booked_cc[:friendly_location_name]).to eq('CC practice name')
      expect(booked_cc[:type_of_care]).to eq('primaryCare')
      expect(booked_cc.as_json).to eq({
                                        'id' => '72106',
                                        'appointment_type' => 'COMMUNITY_CARE',
                                        'cancel_id' => '72106',
                                        'comment' => nil,
                                        'facility_id' => '552',
                                        'sta6aid' => '552',
                                        'healthcare_provider' => nil,
                                        'healthcare_service' => 'CC practice name',
                                        'location' => {
                                          'id' => nil,
                                          'name' => 'CC practice name',
                                          'address' => {
                                            'street' => '1601 Needmore Rd Ste 1',
                                            'city' => 'Dayton',
                                            'state' => 'OH',
                                            'zip_code' => '45414'
                                          },
                                          'lat' => nil,
                                          'long' => nil,
                                          'phone' => {
                                            'area_code' => nil,
                                            'number' => nil,
                                            'extension' => nil
                                          },
                                          'url' => nil,
                                          'code' => nil
                                        },
                                        'minutes_duration' => 60,
                                        'phone_only' => false,
                                        'start_date_local' => '2022-01-11T10:00:00.000-05:00',
                                        'start_date_utc' => '2022-01-11T15:00:00.000+00:00',
                                        'status' => 'BOOKED',
                                        'status_detail' => nil,
                                        'time_zone' => 'America/New_York',
                                        'vetext_id' => nil,
                                        'reason' => nil,
                                        'is_covid_vaccine' => false,
                                        'is_pending' => false,
                                        'proposed_times' => nil,
                                        'type_of_care' => 'primaryCare',
                                        'patient_phone_number' => nil,
                                        'patient_email' => nil,
                                        'best_time_to_call' => nil,
                                        'friendly_location_name' => 'CC practice name'
                                      })
    end
  end

  context 'with a proposed CC appointment' do
    let(:proposed_cc) { adapted_appointments[3] }

    it 'has expected fields' do
      expect(proposed_cc[:is_pending]).to eq(true)
      expect(proposed_cc[:status]).to eq('SUBMITTED')
      expect(proposed_cc[:appointment_type]).to eq('COMMUNITY_CARE')
      expect(proposed_cc[:type_of_care]).to eq('primaryCare')
      expect(proposed_cc[:proposed_times]).to eq([{ "date": '01/26/2022', "time": 'AM' }])
      expect(proposed_cc.as_json).to eq({
                                          'id' => '72105',
                                          'appointment_type' => 'COMMUNITY_CARE',
                                          'cancel_id' => '72105',
                                          'comment' => 'this is a comment',
                                          'facility_id' => '552',
                                          'sta6aid' => '552',
                                          'healthcare_provider' => nil,
                                          'healthcare_service' => nil,
                                          'location' => {
                                            'id' => nil,
                                            'name' => nil,
                                            'address' => {
                                              'street' => nil,
                                              'city' => nil,
                                              'state' => nil,
                                              'zip_code' => nil
                                            },
                                            'lat' => nil,
                                            'long' => nil,
                                            'phone' => {
                                              'area_code' => nil,
                                              'number' => nil,
                                              'extension' => nil
                                            },
                                            'url' => nil,
                                            'code' => nil
                                          },
                                          'minutes_duration' => 60,
                                          'phone_only' => false,
                                          'start_date_local' => '2022-01-25T19:00:00.000-05:00',
                                          'start_date_utc' => '2022-01-26T00:00:00.000+00:00',
                                          'status' => 'SUBMITTED',
                                          'status_detail' => nil,
                                          'time_zone' => 'America/New_York',
                                          'vetext_id' => nil,
                                          'reason' => nil,
                                          'is_covid_vaccine' => false,
                                          'is_pending' => true,
                                          'proposed_times' => [
                                            {
                                              'date' => '01/26/2022',
                                              'time' => 'AM'
                                            }
                                          ],
                                          'type_of_care' => 'primaryCare',
                                          'patient_phone_number' => '2566832029',
                                          'patient_email' => 'Aarathi.poldass@va.gov',
                                          'best_time_to_call' => [
                                            'Morning'
                                          ],
                                          'friendly_location_name' => nil
                                        })
    end
  end

  context 'with a proposed VA appointment' do
    let(:proposed_va) { adapted_appointments[4] }

    it 'has expected fields' do
      expect(proposed_va[:is_pending]).to eq(true)
      expect(proposed_va[:status]).to eq('SUBMITTED')
      expect(proposed_va[:appointment_type]).to eq('VA')
      expect(proposed_va[:healthcare_service]).to eq('Friendly Name Optometry')
      expect(proposed_va[:location][:name]).to eq('Cheyenne VA Medical Center')
      expect(proposed_va[:proposed_times]).to eq([{ "date": '09/28/2021', "time": 'AM' }])
      expect(proposed_va.as_json).to eq({
                                          'id' => '50956',
                                          'appointment_type' => 'VA',
                                          'cancel_id' => '50956',
                                          'comment' => nil,
                                          'facility_id' => '442',
                                          'sta6aid' => '442',
                                          'healthcare_provider' => nil,
                                          'healthcare_service' => 'Friendly Name Optometry',
                                          'location' => {
                                            'id' => '442',
                                            'name' => 'Cheyenne VA Medical Center',
                                            'address' => {
                                              'street' => '2360 East Pershing Boulevard',
                                              'city' => 'Cheyenne',
                                              'state' => 'WY',
                                              'zip_code' => '82001-5356'
                                            },
                                            'lat' => 41.148026,
                                            'long' => -104.786255,
                                            'phone' => {
                                              'area_code' => '307',
                                              'number' => '778-7550',
                                              'extension' => nil
                                            },
                                            'url' => nil,
                                            'code' => nil
                                          },
                                          'minutes_duration' => nil,
                                          'phone_only' => false,
                                          'start_date_local' => '2021-09-27T18:00:00.000-06:00',
                                          'start_date_utc' => '2021-09-28T00:00:00.000+00:00',
                                          'status' => 'SUBMITTED',
                                          'status_detail' => nil,
                                          'time_zone' => 'America/Denver',
                                          'vetext_id' => nil,
                                          'reason' => nil,
                                          'is_covid_vaccine' => false,
                                          'is_pending' => true,
                                          'proposed_times' => [
                                            { 'date' => '09/28/2021', 'time' => 'AM' }
                                          ],
                                          'type_of_care' => nil,
                                          'patient_phone_number' => '7175555555',
                                          'patient_email' => 'Aarathi.poldass@va.gov',
                                          'best_time_to_call' => [
                                            'Evening'
                                          ],
                                          'friendly_location_name' => nil
                                        })
    end
  end

  context 'with a phone VA appointment' do
    let(:phone_va) { adapted_appointments[5] }

    it 'has expected fields' do
      expect(phone_va[:appointment_type]).to eq('VA')
      expect(phone_va[:phone_only]).to eq(true)
      expect(phone_va.as_json).to eq({
                                       'id' => '53352',
                                       'appointment_type' => 'VA',
                                       'cancel_id' => '53352',
                                       'comment' => nil,
                                       'facility_id' => '442',
                                       'sta6aid' => '442',
                                       'healthcare_provider' => nil,
                                       'healthcare_service' => 'Friendly Name Optometry',
                                       'location' => {
                                         'id' => '442',
                                         'name' => 'Cheyenne VA Medical Center',
                                         'address' => {
                                           'street' => '2360 East Pershing Boulevard',
                                           'city' => 'Cheyenne',
                                           'state' => 'WY',
                                           'zip_code' => '82001-5356'
                                         },
                                         'lat' => 41.148026,
                                         'long' => -104.786255,
                                         'phone' => {
                                           'area_code' => '307',
                                           'number' => '778-7550',
                                           'extension' => nil
                                         },
                                         'url' => nil,
                                         'code' => nil
                                       },
                                       'minutes_duration' => nil,
                                       'phone_only' => true,
                                       'start_date_local' => '2021-10-01T06:00:00.000-06:00',
                                       'start_date_utc' => '2021-10-01T12:00:00.000+00:00',
                                       'status' => 'SUBMITTED',
                                       'status_detail' => nil,
                                       'time_zone' => 'America/Denver',
                                       'vetext_id' => nil,
                                       'reason' => nil,
                                       'is_covid_vaccine' => false,
                                       'is_pending' => true,
                                       'proposed_times' => [
                                         { 'date' => '10/01/2021', 'time' => 'PM' },
                                         { 'date' => '01/03/2022', 'time' => 'PM' }
                                       ],
                                       'type_of_care' => nil,
                                       'patient_phone_number' => '7175555555',
                                       'patient_email' => 'judy.morrison@id.me',
                                       'best_time_to_call' => [
                                         'Morning'
                                       ],
                                       'friendly_location_name' => nil
                                     })
    end
  end
end
