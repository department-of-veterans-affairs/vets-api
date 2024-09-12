# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::VAOSV2Appointments, :aggregate_failures do
  # while hashes will work for these tests, this better reflects the data returned from the VAOS service
  def appointment_data(index = nil)
    appts = index ? raw_data[index] : raw_data
    Array.wrap(appts).map { |appt| OpenStruct.new(appt) }
  end

  def appointment_by_id(id)
    raw_data.find { |appt| appt[:id] == id }
  end

  def adapted_appointment_by_id(id)
    parse_appointment(appointment_by_id(id))
  end

  def parse_appointment(appt)
    subject.parse(Array.wrap(appt)).first
  end

  let(:raw_data) { JSON.parse(appointment_fixtures, symbolize_names: true) }
  let(:appointment_fixtures) do
    File.read(Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'VAOS_v2_appointments.json'))
  end
  let(:adapted_appointment) { ->(index) { parse_appointment(appointment_data(index)) } }
  # let(:adapted_appointment_by_id) { ->(id) { parse_appointment(appointment_by_id(id)) } }

  let(:adapted_appointments) do
    subject.parse(appointment_data)
  end
  let(:parsed_appointment) { parse_appointment(appointment) }

  let(:cancelled_va_id) { '121133' }
  let(:booked_va_id) { '121134' }
  let(:booked_cc_id) { '72106' }
  let(:proposed_cc_id) { '72105' }
  let(:proposed_va_id) { '50956' }
  let(:phone_va_id) { '53352' }
  let(:home_va_id) { '50094' }
  let(:atlas_va_id) { '50095' }
  let(:home_gfe_id) { '50096' }
  let(:past_request_date_appt_id) { '53360' }
  let(:future_request_date_appt_id) { '53359' }
  let(:cancelled_requested_va_appt_id) { '53241' }
  let(:acheron_appointment_id) { '145078' }
  let(:telehealth_onsite_id) { '50097' }

  before do
    Timecop.freeze(Time.zone.parse('2022-08-25T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  it 'returns an empty array when provided nil' do
    expect(subject.parse(nil)).to eq([])
  end

  it 'returns a list of appointments at the expected size' do
    expect(adapted_appointments.size).to eq(14)
  end

  context 'with a cancelled VA appointment' do
    let(:cancelled_va) { adapted_appointment_by_id(cancelled_va_id) }

    it 'has expected fields' do
      expect(cancelled_va[:status_detail]).to eq('CANCELLED BY PATIENT')
      expect(cancelled_va[:status]).to eq('CANCELLED')
      expect(cancelled_va[:appointment_type]).to eq('VA')
      expect(cancelled_va[:is_pending]).to eq(false)
      expect(cancelled_va.as_json).to eq({ 'id' => cancelled_va_id,
                                           'appointment_type' => 'VA',
                                           'appointment_ien' => nil,
                                           'cancel_id' => nil,
                                           'comment' => 'This is a free form comment',
                                           'facility_id' => '442',
                                           'sta6aid' => '442',
                                           'healthcare_provider' => nil,
                                           'healthcare_service' => nil,
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
                                           'physical_location' => nil,
                                           'minutes_duration' => 30,
                                           'phone_only' => false,
                                           'start_date_local' => '2022-08-27T09:45:00.000-06:00',
                                           'start_date_utc' => '2022-08-27T15:45:00.000+00:00',
                                           'status' => 'CANCELLED',
                                           'status_detail' => 'CANCELLED BY PATIENT',
                                           'time_zone' => 'America/Denver',
                                           'vetext_id' => '442;3220827.0945',
                                           'reason' => nil,
                                           'is_covid_vaccine' => false,
                                           'is_pending' => false,
                                           'proposed_times' => nil,
                                           'type_of_care' => 'Optometry',
                                           'patient_phone_number' => nil,
                                           'patient_email' => nil,
                                           'best_time_to_call' => nil,
                                           'friendly_location_name' => 'Cheyenne VA Medical Center',
                                           'service_category_name' => nil })
    end
  end

  context 'with a booked VA appointment' do
    let(:booked_va) { adapted_appointment_by_id(booked_va_id) }

    it 'has expected fields' do
      expect(booked_va[:status]).to eq('BOOKED')
      expect(booked_va[:appointment_type]).to eq('VA')
      expect(booked_va.as_json).to eq({
                                        'id' => booked_va_id,
                                        'appointment_type' => 'VA',
                                        'appointment_ien' => nil,
                                        'cancel_id' => nil,
                                        'comment' => nil,
                                        'facility_id' => '442',
                                        'sta6aid' => '442',
                                        'healthcare_provider' => nil,
                                        'healthcare_service' => nil,
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
                                        'physical_location' => nil,
                                        'minutes_duration' => 30,
                                        'phone_only' => false,
                                        'start_date_local' => '2018-03-07T00:00:00.000-07:00',
                                        'start_date_utc' => '2018-03-07T07:00:00.000+00:00',
                                        'status' => 'BOOKED',
                                        'status_detail' => nil,
                                        'time_zone' => 'America/Denver',
                                        'vetext_id' => '442;3180307.0',
                                        'reason' => nil,
                                        'is_covid_vaccine' => false,
                                        'is_pending' => false,
                                        'proposed_times' => nil,
                                        'type_of_care' => 'Optometry',
                                        'patient_phone_number' => nil,
                                        'patient_email' => nil,
                                        'best_time_to_call' => nil,
                                        'friendly_location_name' => 'Cheyenne VA Medical Center',
                                        'service_category_name' => nil
                                      })
    end
  end

  context 'with a booked CC appointment' do
    let(:booked_cc) { adapted_appointment_by_id(booked_cc_id) }

    it 'has expected fields' do
      expect(booked_cc[:status]).to eq('BOOKED')
      expect(booked_cc[:appointment_type]).to eq('COMMUNITY_CARE')
      expect(booked_cc[:location][:name]).to eq('CC practice name')
      expect(booked_cc[:friendly_location_name]).to eq('CC practice name')
      expect(booked_cc[:type_of_care]).to eq('Primary Care')
      expect(booked_cc.as_json).to eq({
                                        'id' => booked_cc_id,
                                        'appointment_type' => 'COMMUNITY_CARE',
                                        'appointment_ien' => nil,
                                        'cancel_id' => booked_cc_id,
                                        'comment' => nil,
                                        'facility_id' => '552',
                                        'sta6aid' => '552',
                                        'healthcare_provider' => nil,
                                        'healthcare_service' => nil,
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
                                            'area_code' => '321',
                                            'number' => '417-0822',
                                            'extension' => nil
                                          },
                                          'url' => nil,
                                          'code' => nil
                                        },
                                        'physical_location' => nil,
                                        'minutes_duration' => 60,
                                        'phone_only' => false,
                                        'start_date_local' => '2022-01-11T08:00:00.000-07:00',
                                        'start_date_utc' => '2022-01-11T15:00:00.000+00:00',
                                        'status' => 'BOOKED',
                                        'status_detail' => nil,
                                        'time_zone' => 'America/Denver',
                                        'vetext_id' => '552;3220111.08',
                                        'reason' => nil,
                                        'is_covid_vaccine' => false,
                                        'is_pending' => false,
                                        'proposed_times' => nil,
                                        'type_of_care' => 'Primary Care',
                                        'patient_phone_number' => nil,
                                        'patient_email' => nil,
                                        'best_time_to_call' => nil,
                                        'friendly_location_name' => 'CC practice name',
                                        'service_category_name' => nil
                                      })
    end
  end

  context 'with a proposed CC appointment' do
    let(:proposed_cc) { adapted_appointment_by_id(proposed_cc_id) }

    it 'has expected fields' do
      expect(proposed_cc[:is_pending]).to eq(true)
      expect(proposed_cc[:status]).to eq('SUBMITTED')
      expect(proposed_cc[:appointment_type]).to eq('COMMUNITY_CARE')
      expect(proposed_cc[:type_of_care]).to eq('Primary Care')
      expect(proposed_cc[:proposed_times]).to eq([{ "date": '01/26/2022', "time": 'AM' }])
      expect(proposed_cc.as_json).to eq({
                                          'id' => proposed_cc_id,
                                          'appointment_type' => 'COMMUNITY_CARE',
                                          'appointment_ien' => nil,
                                          'cancel_id' => proposed_cc_id,
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
                                          'physical_location' => nil,
                                          'minutes_duration' => 60,
                                          'phone_only' => false,
                                          'start_date_local' => '2022-01-25T17:00:00.000-07:00',
                                          'start_date_utc' => '2022-01-26T00:00:00.000+00:00',
                                          'status' => 'SUBMITTED',
                                          'status_detail' => nil,
                                          'time_zone' => 'America/Denver',
                                          'vetext_id' => '552;3220125.17',
                                          'reason' => nil,
                                          'is_covid_vaccine' => false,
                                          'is_pending' => true,
                                          'proposed_times' => [
                                            {
                                              'date' => '01/26/2022',
                                              'time' => 'AM'
                                            }
                                          ],
                                          'type_of_care' => 'Primary Care',
                                          'patient_phone_number' => '256-683-2029',
                                          'patient_email' => 'Aarathi.poldass@va.gov',
                                          'best_time_to_call' => [
                                            'Morning'
                                          ],
                                          'friendly_location_name' => 'Cheyenne VA Medical Center',
                                          'service_category_name' => nil
                                        })
    end
  end

  context 'with a proposed VA appointment' do
    let(:proposed_va) { adapted_appointment_by_id(proposed_va_id) }

    it 'has expected fields' do
      expect(proposed_va[:is_pending]).to eq(true)
      expect(proposed_va[:status]).to eq('SUBMITTED')
      expect(proposed_va[:appointment_type]).to eq('VA')
      expect(proposed_va[:location][:name]).to eq('Cheyenne VA Medical Center')
      expect(proposed_va[:proposed_times]).to eq([{ "date": '09/28/2021', "time": 'AM' }])
      expect(proposed_va.as_json).to eq({
                                          'id' => proposed_va_id,
                                          'appointment_type' => 'VA',
                                          'appointment_ien' => nil,
                                          'cancel_id' => proposed_va_id,
                                          'comment' => nil,
                                          'facility_id' => '442',
                                          'sta6aid' => '442',
                                          'healthcare_provider' => nil,
                                          'healthcare_service' => nil,
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
                                          'physical_location' => nil,
                                          'minutes_duration' => nil,
                                          'phone_only' => false,
                                          'start_date_local' => '2021-09-27T18:00:00.000-06:00',
                                          'start_date_utc' => '2021-09-28T00:00:00.000+00:00',
                                          'status' => 'SUBMITTED',
                                          'status_detail' => nil,
                                          'time_zone' => 'America/Denver',
                                          'vetext_id' => '442;3210927.18',
                                          'reason' => nil,
                                          'is_covid_vaccine' => false,
                                          'is_pending' => true,
                                          'proposed_times' => [
                                            { 'date' => '09/28/2021', 'time' => 'AM' }
                                          ],
                                          'type_of_care' => 'Social Work',
                                          'patient_phone_number' => '717-555-5555',
                                          'patient_email' => 'Aarathi.poldass@va.gov',
                                          'best_time_to_call' => [
                                            'Evening'
                                          ],
                                          'friendly_location_name' => 'Cheyenne VA Medical Center',
                                          'service_category_name' => nil
                                        })
    end
  end

  context 'with a phone VA appointment' do
    let(:phone_va) { adapted_appointment_by_id(phone_va_id) }

    it 'has expected fields' do
      expect(phone_va[:appointment_type]).to eq('VA')
      expect(phone_va[:phone_only]).to eq(true)
      expect(phone_va.as_json).to eq({
                                       'id' => phone_va_id,
                                       'appointment_type' => 'VA',
                                       'appointment_ien' => nil,
                                       'cancel_id' => phone_va_id,
                                       'comment' => nil,
                                       'facility_id' => '442',
                                       'sta6aid' => '442',
                                       'healthcare_provider' => nil,
                                       'healthcare_service' => nil,
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
                                       'physical_location' => nil,
                                       'minutes_duration' => nil,
                                       'phone_only' => true,
                                       'start_date_local' => '2021-10-01T06:00:00.000-06:00',
                                       'start_date_utc' => '2021-10-01T12:00:00.000+00:00',
                                       'status' => 'SUBMITTED',
                                       'status_detail' => nil,
                                       'time_zone' => 'America/Denver',
                                       'vetext_id' => '442;3211001.06',
                                       'reason' => nil,
                                       'is_covid_vaccine' => false,
                                       'is_pending' => true,
                                       'proposed_times' => [
                                         { 'date' => '10/01/2021', 'time' => 'PM' }
                                       ],
                                       'type_of_care' => 'Primary Care',
                                       'patient_phone_number' => '717-555-5555',
                                       'patient_email' => 'judy.morrison@id.me',
                                       'best_time_to_call' => [
                                         'Morning'
                                       ],
                                       'friendly_location_name' => 'Cheyenne VA Medical Center',
                                       'service_category_name' => nil
                                     })
    end
  end

  context 'with a telehealth Home appointment' do
    let(:home_va) { adapted_appointment_by_id(home_va_id) }

    it 'has expected fields' do
      expect(home_va[:appointment_type]).to eq('VA_VIDEO_CONNECT_HOME')
      expect(home_va[:location][:name]).to eq('Cheyenne VA Medical Center')
      expect(home_va[:location][:url]).to eq('http://www.meeting.com')

      expect(home_va.as_json).to eq({ 'id' => home_va_id,
                                      'appointment_type' => 'VA_VIDEO_CONNECT_HOME',
                                      'appointment_ien' => nil,
                                      'cancel_id' => nil,
                                      'comment' => nil,
                                      'facility_id' => '442',
                                      'sta6aid' => '442',
                                      'healthcare_provider' => nil,
                                      'healthcare_service' => nil,
                                      'location' =>
                                       { 'id' => nil,
                                         'name' => 'Cheyenne VA Medical Center',
                                         'address' =>
                                          { 'street' => nil, 'city' => nil, 'state' => nil, 'zip_code' => nil },
                                         'lat' => nil,
                                         'long' => nil,
                                         'phone' => { 'area_code' => '307', 'number' => '778-7550',
                                                      'extension' => nil },
                                         'url' => 'http://www.meeting.com',
                                         'code' => nil },
                                      'physical_location' => nil,
                                      'minutes_duration' => nil,
                                      'phone_only' => false,
                                      'start_date_local' => '2021-09-08T06:00:00.000-06:00',
                                      'start_date_utc' => '2021-09-08T12:00:00.000+00:00',
                                      'status' => 'SUBMITTED',
                                      'status_detail' => nil,
                                      'time_zone' => 'America/Denver',
                                      'vetext_id' => '442;3210908.06',
                                      'reason' => nil,
                                      'is_covid_vaccine' => false,
                                      'is_pending' => true,
                                      'proposed_times' => [{ 'date' => '09/08/2021', 'time' => 'PM' }],
                                      'type_of_care' => 'Primary Care',
                                      'patient_phone_number' => '999-999-9992',
                                      'patient_email' => nil,
                                      'best_time_to_call' => nil,
                                      'friendly_location_name' => 'Cheyenne VA Medical Center',
                                      'service_category_name' => nil })
    end
  end

  context 'with a telehealth Atlas appointment' do
    let(:atlas_va) { adapted_appointment_by_id(atlas_va_id) }

    it 'has expected fields' do
      expect(atlas_va[:appointment_type]).to eq('VA_VIDEO_CONNECT_ATLAS')
      expect(atlas_va[:location][:name]).to eq('Cheyenne VA Medical Center')
      expect(atlas_va[:location][:address].to_h).to eq({ street: '114 Dewey Ave',
                                                         city: 'Eureka',
                                                         state: 'MT',
                                                         zip_code: '59917' })
      expect(atlas_va[:location][:url]).to eq('http://www.meeting.com')
      expect(atlas_va[:location][:code]).to eq('420835')

      expect(atlas_va.as_json).to eq({ 'id' => atlas_va_id,
                                       'appointment_type' => 'VA_VIDEO_CONNECT_ATLAS',
                                       'appointment_ien' => nil,
                                       'cancel_id' => nil,
                                       'comment' => nil,
                                       'facility_id' => '442',
                                       'sta6aid' => '442',
                                       'healthcare_provider' => nil,
                                       'healthcare_service' => nil,
                                       'location' =>
                                        { 'id' => nil,
                                          'name' => 'Cheyenne VA Medical Center',
                                          'address' =>
                                           { 'street' => '114 Dewey Ave',
                                             'city' => 'Eureka',
                                             'state' => 'MT',
                                             'zip_code' => '59917' },
                                          'lat' => nil,
                                          'long' => nil,
                                          'phone' => { 'area_code' => '307', 'number' => '778-7550',
                                                       'extension' => nil },
                                          'url' => 'http://www.meeting.com',
                                          'code' => '420835' },
                                       'physical_location' => nil,
                                       'minutes_duration' => nil,
                                       'phone_only' => false,
                                       'start_date_local' => '2021-09-08T06:00:00.000-06:00',
                                       'start_date_utc' => '2021-09-08T12:00:00.000+00:00',
                                       'status' => 'SUBMITTED',
                                       'status_detail' => nil,
                                       'time_zone' => 'America/Denver',
                                       'vetext_id' => '442;3210908.06',
                                       'reason' => nil,
                                       'is_covid_vaccine' => false,
                                       'is_pending' => true,
                                       'proposed_times' => [{ 'date' => '09/08/2021', 'time' => 'PM' }],
                                       'type_of_care' => 'Primary Care',
                                       'patient_phone_number' => '999-999-9992',
                                       'patient_email' => nil,
                                       'best_time_to_call' => nil,
                                       'friendly_location_name' => 'Cheyenne VA Medical Center',
                                       'service_category_name' => nil })
    end
  end

  context 'with a GFE appointment' do
    let(:home_gfe) { adapted_appointment_by_id(home_gfe_id) }

    it 'has expected fields' do
      expect(home_gfe[:appointment_type]).to eq('VA_VIDEO_CONNECT_GFE')
      expect(home_gfe[:location][:name]).to eq('Cheyenne VA Medical Center')
      expect(home_gfe[:location][:url]).to eq('http://www.meeting.com')

      expect(home_gfe.as_json).to eq({ 'id' => home_gfe_id,
                                       'appointment_type' => 'VA_VIDEO_CONNECT_GFE',
                                       'appointment_ien' => nil,
                                       'cancel_id' => nil,
                                       'comment' => nil,
                                       'facility_id' => '442',
                                       'sta6aid' => '442',
                                       'healthcare_provider' => nil,
                                       'healthcare_service' => nil,
                                       'location' =>
                                      { 'id' => nil,
                                        'name' => 'Cheyenne VA Medical Center',
                                        'address' =>
                                         { 'street' => nil, 'city' => nil, 'state' => nil, 'zip_code' => nil },
                                        'lat' => nil,
                                        'long' => nil,
                                        'phone' => { 'area_code' => '307', 'number' => '778-7550', 'extension' => nil },
                                        'url' => 'http://www.meeting.com',
                                        'code' => nil },
                                       'physical_location' => nil,
                                       'minutes_duration' => nil,
                                       'phone_only' => false,
                                       'start_date_local' => '2021-09-08T06:00:00.000-06:00',
                                       'start_date_utc' => '2021-09-08T12:00:00.000+00:00',
                                       'status' => 'SUBMITTED',
                                       'status_detail' => nil,
                                       'time_zone' => 'America/Denver',
                                       'vetext_id' => '442;3210908.06',
                                       'reason' => nil,
                                       'is_covid_vaccine' => false,
                                       'is_pending' => true,
                                       'proposed_times' => [{ 'date' => '09/08/2021', 'time' => 'PM' }],
                                       'type_of_care' => 'Primary Care',
                                       'patient_phone_number' => '999-999-9992',
                                       'patient_email' => nil,
                                       'best_time_to_call' => nil,
                                       'friendly_location_name' => 'Cheyenne VA Medical Center',
                                       'service_category_name' => nil })
    end
  end

  context 'with a telehealth on site appointment' do
    let(:telehealth_onsite) { adapted_appointment_by_id(telehealth_onsite_id) }

    it 'has expected fields' do
      expect(telehealth_onsite[:appointment_type]).to eq('VA_VIDEO_CONNECT_ONSITE')
      expect(telehealth_onsite[:location][:name]).to eq('Cheyenne VA Medical Center')
      expect(telehealth_onsite[:location][:url]).to eq(nil)

      expect(telehealth_onsite.as_json).to eq({ 'id' => telehealth_onsite_id,
                                                'appointment_type' => 'VA_VIDEO_CONNECT_ONSITE',
                                                'appointment_ien' => nil,
                                                'cancel_id' => nil,
                                                'comment' => nil,
                                                'facility_id' => '442',
                                                'sta6aid' => '442',
                                                'healthcare_provider' => nil,
                                                'healthcare_service' => nil,
                                                'location' =>
                                                  { 'id' => '442',
                                                    'name' => 'Cheyenne VA Medical Center',
                                                    'address' =>
                                                     { 'street' => '2360 East Pershing Boulevard',
                                                       'city' => 'Cheyenne',
                                                       'state' => 'WY',
                                                       'zip_code' => '82001-5356' },
                                                    'lat' => 41.148026,
                                                    'long' => -104.786255,
                                                    'phone' =>
                                                     { 'area_code' => '307',
                                                       'number' => '778-7550',
                                                       'extension' => nil },
                                                    'url' => nil,
                                                    'code' => nil },
                                                'physical_location' => nil,
                                                'minutes_duration' => nil,
                                                'phone_only' => false,
                                                'start_date_local' => '2021-09-08T06:00:00.000-06:00',
                                                'start_date_utc' => '2021-09-08T12:00:00.000+00:00',
                                                'status' => 'SUBMITTED',
                                                'status_detail' => nil,
                                                'time_zone' => 'America/Denver',
                                                'vetext_id' => '442;3210908.06',
                                                'reason' => nil,
                                                'is_covid_vaccine' => false,
                                                'is_pending' => true,
                                                'proposed_times' => [{ 'date' => '09/08/2021', 'time' => 'PM' }],
                                                'type_of_care' => 'Primary Care',
                                                'patient_phone_number' => '999-999-9992',
                                                'patient_email' => nil,
                                                'best_time_to_call' => nil,
                                                'friendly_location_name' => 'Cheyenne VA Medical Center',
                                                'service_category_name' => nil })
    end
  end

  context 'with a cancelled requested VA appointment' do
    let(:cancelled_requested_va_appt) { adapted_appointment_by_id(cancelled_requested_va_appt_id) }

    it 'has expected fields' do
      expect(cancelled_requested_va_appt[:appointment_type]).to eq('VA')
      expect(cancelled_requested_va_appt[:is_pending]).to eq(true)
      expect(cancelled_requested_va_appt[:status]).to eq('CANCELLED')

      expect(cancelled_requested_va_appt.as_json).to eq({
                                                          'id' => '53241',
                                                          'appointment_type' => 'VA',
                                                          'appointment_ien' => nil,
                                                          'cancel_id' => nil,
                                                          'comment' => 'testing',
                                                          'facility_id' => '442',
                                                          'sta6aid' => '442',
                                                          'healthcare_provider' => nil,
                                                          'healthcare_service' => nil,
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
                                                          'physical_location' => nil,
                                                          'minutes_duration' => nil,
                                                          'phone_only' => false,
                                                          'start_date_local' => '2017-05-15T18:00:00.000-06:00',
                                                          'start_date_utc' => '2017-05-16T00:00:00.000+00:00',
                                                          'status' => 'CANCELLED',
                                                          'status_detail' => 'CANCELLED BY CLINIC',
                                                          'time_zone' => 'America/Denver',
                                                          'vetext_id' => '442;3170515.18',
                                                          'reason' => 'Routine Follow-up',
                                                          'is_covid_vaccine' => false,
                                                          'is_pending' => true,
                                                          'proposed_times' => [
                                                            { 'date' => '05/16/2017', 'time' => 'AM' },
                                                            { 'date' => '05/17/2017', 'time' => 'AM' },
                                                            { 'date' => '05/31/2017', 'time' => 'AM' }
                                                          ],
                                                          'type_of_care' => 'Primary Care',
                                                          'patient_phone_number' => '788-999-9999',
                                                          'patient_email' => nil,
                                                          'best_time_to_call' => [
                                                            'Afternoon'
                                                          ],
                                                          'friendly_location_name' => 'Cheyenne VA Medical Center',
                                                          'service_category_name' => nil
                                                        })
    end
  end

  describe 'times' do
    context 'request periods that are in the future' do
      let(:future_request_date_appt) { adapted_appointment_by_id(future_request_date_appt_id) }

      it 'sets start date to earliest date in the future' do
        expect(future_request_date_appt[:start_date_local]).to eq('2022-08-27T12:00:00Z')
        expect(future_request_date_appt[:proposed_times]).to eq([{ date: '08/20/2022', time: 'PM' },
                                                                { date: '08/27/2022', time: 'PM' },
                                                                { date: '10/03/2022', time: 'PM' }])
        expect(future_request_date_appt[:time_zone]).to eq('America/Denver')
      end
    end

    context 'request periods that are in the past' do
      let(:past_request_date_appt) { adapted_appointment_by_id(past_request_date_appt_id) }

      it 'sets start date to earliest date' do
        expect(past_request_date_appt[:start_date_local]).to eq('2021-08-20T12:00:00Z')
        expect(past_request_date_appt[:proposed_times]).to eq([{ date: '08/20/2021', time: 'PM' },
                                                              { date: '08/27/2021', time: 'PM' },
                                                              { date: '10/03/2021', time: 'PM' }])
        expect(past_request_date_appt[:time_zone]).to eq('America/Denver')
      end
    end

    context 'with no timezone' do
      let(:no_timezone_appt) do
        vaos_data = JSON.parse(appointment_fixtures, symbolize_names: true)
        vaos_data.dig(0, :location).delete(:timezone)
        appointments = subject.parse(vaos_data)
        appointments[0]
      end

      it 'falls back to hardcoded timezone lookup' do
        expect(no_timezone_appt[:start_date_local]).to eq('2022-08-27 09:45:00 -0600"')
        expect(no_timezone_appt[:start_date_utc]).to eq('2022-08-27T15:45:00Z')
        expect(no_timezone_appt[:time_zone]).to eq('America/Denver')
      end
    end
  end

  describe 'type_of_care' do
    let(:vaos_data) { appointment_by_id(booked_va_id) }

    context 'with nil service type' do
      it 'returns nil' do
        vaos_data[:service_type] = nil
        nil_service_type = subject.parse([vaos_data]).first
        expect(nil_service_type[:type_of_care]).to eq(nil)
      end
    end

    context 'with known service type' do
      it 'returns appropriate copy for the service type' do
        vaos_data[:service_type] = 'outpatientMentalHealth'
        known_service_type = subject.parse([vaos_data]).first
        expect(known_service_type[:type_of_care]).to eq('Mental Health')
      end
    end

    context 'with unknown service type' do
      it 'returns a capitalized version of the service type' do
        vaos_data[:service_type] = 'hey there'
        unknown_service_type = subject.parse([vaos_data]).first
        expect(unknown_service_type[:type_of_care]).to eq('Hey There')
      end
    end
  end

  # very incomplete
  describe 'status' do
    context 'when arrived' do
      let(:arrived_appt) do
        vaos_data = JSON.parse(appointment_fixtures, symbolize_names: true)[1]
        vaos_data[:status] = 'arrived'
        subject.parse([vaos_data])
      end

      it 'converts status to BOOKED' do
        expect(arrived_appt.first[:status]).to eq('BOOKED')
      end
    end
  end

  describe 'patient phone number' do
    let(:home_va) { appointment_by_id(atlas_va_id) }

    it 'formats phone number with parentheses' do
      home_va[:contact][:telecom][0][:value] = '(480)-293-1922'
      parentheses_phone_num_appt = subject.parse([home_va]).first
      expect(parentheses_phone_num_appt[:patient_phone_number]).to eq('480-293-1922')
    end

    it 'formats phone number with parentheses and no first dash' do
      home_va[:contact][:telecom][0][:value] = '(480) 293-1922'
      parentheses_no_dash_phone_num_appt = subject.parse([home_va]).first
      expect(parentheses_no_dash_phone_num_appt[:patient_phone_number]).to eq('480-293-1922')
    end

    it 'formats phone number with no dashes' do
      home_va[:contact][:telecom][0][:value] = '4802931922'
      no_dashes_phone_num_appt = subject.parse([home_va]).first
      expect(no_dashes_phone_num_appt[:patient_phone_number]).to eq('480-293-1922')
    end

    it 'does not change phone number with correct format' do
      home_va[:contact][:telecom][0][:value] = '480-293-1922'
      no_parentheses_phone_num_appt = subject.parse([home_va]).first
      expect(no_parentheses_phone_num_appt[:patient_phone_number]).to eq('480-293-1922')
    end
  end

  describe 'embedded acheron values' do
    let(:acheron_appointment) { adapted_appointment_by_id(acheron_appointment_id) }

    # these tests are duplicative of the full body test but are meant to highlight the relevant data
    it 'parses values out of the reason code' do
      expect(acheron_appointment.patient_email).to eq('melissa.gra@va.gov')
      expect(acheron_appointment.patient_phone_number).to eq('317-448-5062')
      expect(acheron_appointment.proposed_times).to eq([{ date: '12/13/2022', time: 'PM' },
                                                        { date: '12/21/2022', time: 'AM' }])
      expect(acheron_appointment.comment).to eq('My leg!')
      expect(acheron_appointment.reason).to eq('Routine Follow-up')
    end

    it 'parses all fields predictably' do
      expect(acheron_appointment.as_json).to eq(
        {
          'id' => acheron_appointment_id,
          'appointment_type' => 'VA',
          'appointment_ien' => nil,
          'cancel_id' => acheron_appointment_id,
          'comment' => 'My leg!',
          'facility_id' => '552',
          'sta6aid' => '552',
          'healthcare_provider' => nil,
          'healthcare_service' => nil,
          'location' => {
            'id' => '984',
            'name' => 'Dayton VA Medical Center',
            'address' => {
              'street' => '4100 West Third Street',
              'city' => 'Dayton',
              'state' => 'OH',
              'zip_code' => '45428-9000'
            },
            'lat' => 39.74935,
            'long' => -84.2532,
            'phone' => { 'area_code' => '937', 'number' => '268-6511',
                         'extension' => nil },
            'url' => nil,
            'code' => nil
          },
          'physical_location' => nil,
          'minutes_duration' => nil,
          'phone_only' => false,
          'start_date_local' => '2022-12-12T19:00:00.000-05:00',
          'start_date_utc' => '2022-12-13T00:00:00.000+00:00',
          'status' => 'SUBMITTED',
          'status_detail' => nil,
          'time_zone' => 'America/New_York',
          'vetext_id' => '552;3221212.19',
          'reason' => 'Routine Follow-up',
          'is_covid_vaccine' => false,
          'is_pending' => true,
          'proposed_times' => [{ 'date' => '12/13/2022', 'time' => 'PM' },
                               { 'date' => '12/21/2022', 'time' => 'AM' }],
          'type_of_care' => 'Amputation care',
          'patient_phone_number' => '317-448-5062',
          'patient_email' => 'melissa.gra@va.gov',
          'best_time_to_call' => nil,
          'friendly_location_name' => 'Dayton VA Medical Center',
          'service_category_name' => 'REGULAR'
        }
      )
    end
  end

  describe 'healthcare provider' do
    let(:practitioner_list) do
      [
        {
          "identifier": [{ "system": 'dfn-983', "value": '520647609' }],
          "name": { "family": 'ENGHAUSER', "given": ['MATTHEW'] },
          "practice_name": 'Site #983'
        },
        {
          "identifier": [{ "system": 'dfn-983', "value": '520647609' }],
          "name": { "family": 'FORTH', "given": ['SALLY'] },
          "practice_name": 'Site #983'
        }
      ]
    end

    it 'uses the first practitioner name in the list' do
      appointment = appointment_data[0]
      appointment[:preferred_provider_name] = 'Dr. Hauser'
      appointment[:practitioners] = practitioner_list
      result = subject.parse([appointment]).first
      expect(result.healthcare_provider).to eq('MATTHEW ENGHAUSER')
    end

    it 'uses the preferred_provider_name if no practitioner list exists' do
      appointment = appointment_data[0]
      appointment[:preferred_provider_name] = 'Dr. Hauser'
      result = subject.parse([appointment]).first

      expect(result.healthcare_provider).to eq('Dr. Hauser')
    end

    it 'converts not found message to nil' do
      appointment = appointment_data[0]
      appointment[:preferred_provider_name] = VAOS::V2::AppointmentProviderName::NPI_NOT_FOUND_MSG
      result = subject.parse([appointment]).first

      expect(result.healthcare_provider).to eq(nil)
    end

    it 'uses the practitioners list in favor of the not found message' do
      appointment = appointment_data[0]
      appointment[:preferred_provider_name] = VAOS::V2::AppointmentProviderName::NPI_NOT_FOUND_MSG
      appointment[:practitioners] = practitioner_list
      result = subject.parse([appointment]).first
      expect(result.healthcare_provider).to eq('MATTHEW ENGHAUSER')
    end
  end

  describe 'location' do
    context 'with a cc appointment request' do
      let(:practitioner_list) do
        [
          {
            "identifier": [
              {
                "system": 'http://hl7.org/fhir/sid/us-npi',
                "value": '1780671644'
              }
            ],
            "address": {
              "type": 'physical',
              "line": [
                '161 MADISON AVE STE 7SW'
              ],
              "city": 'NEW YORK',
              "state": 'NY',
              "postal_code": '10016-5448',
              "text": '161 MADISON AVE STE 7SW,NEW YORK,NY,10016-5448'
            }
          }
        ]
      end

      it 'sets location from practitioners list' do
        proposed_cc = appointment_by_id(proposed_cc_id)
        proposed_cc[:practitioners] = practitioner_list
        result = subject.parse([proposed_cc]).first
        expect(result[:location].to_h).to eq({
                                               id: nil,
                                               name: nil,
                                               address: { street: '161 MADISON AVE STE 7SW', city: 'NEW YORK',
                                                          state: 'NY', zip_code: '10016-5448' },
                                               lat: nil,
                                               long: nil,
                                               phone: { area_code: nil, number: nil, extension: nil },
                                               url: nil,
                                               code: nil
                                             })
      end
    end

    context 'with a cc appointment' do
      it 'sets location from cc_location' do
        booked_cc = adapted_appointment_by_id(booked_cc_id)
        expect(booked_cc[:location].to_h).to eq(
          {
            id: nil,
            name: 'CC practice name',
            address: { street: '1601 Needmore Rd Ste 1', city: 'Dayton', state: 'OH',
                       zip_code: '45414' },
            lat: nil,
            long: nil,
            phone: { area_code: '321', number: '417-0822', extension: nil },
            url: nil,
            code: nil
          }
        )
      end
    end

    context 'with telehealth appointment' do
      it 'sets location from appointment location attributes' do
        atlas_va = adapted_appointment_by_id(atlas_va_id)
        expect(atlas_va[:location].to_h).to eq(
          {
            id: nil,
            name: 'Cheyenne VA Medical Center',
            address: { street: '114 Dewey Ave', city: 'Eureka', state: 'MT', zip_code: '59917' },
            lat: nil,
            long: nil,
            phone: { area_code: '307', number: '778-7550', extension: nil },
            url: 'http://www.meeting.com',
            code: '420835'
          }
        )
      end
    end

    context 'with a VA appointment' do
      it 'sets location from appointment location attributes' do
        booked_va = adapted_appointment_by_id(booked_va_id)
        expect(booked_va[:location].to_h).to eq(
          {
            id: '442',
            name: 'Cheyenne VA Medical Center',
            address: { street: '2360 East Pershing Boulevard', city: 'Cheyenne', state: 'WY',
                       zip_code: '82001-5356' },
            lat: 41.148026,
            long: -104.786255,
            phone: { area_code: '307', number: '778-7550', extension: nil },
            url: nil,
            code: nil
          }
        )
      end
    end
  end

  describe 'friendly_location_name' do
    context 'with VA appointment' do
      let(:appointment) { appointment_by_id(booked_va_id) }

      it 'is set to location name' do
        expect(parsed_appointment[:friendly_location_name]).to eq('Cheyenne VA Medical Center')
      end

      it 'is set to nil when location name is absent' do
        appointment.delete(:location)
        expect(parsed_appointment[:friendly_location_name]).to eq(nil)
      end
    end

    context 'with CC appointment request' do
      let(:appointment) { appointment_by_id(proposed_cc_id) }

      it 'is set to location name' do
        expect(parsed_appointment[:friendly_location_name]).to eq('Cheyenne VA Medical Center')
      end

      it 'is set to nil when location name is absent' do
        appointment.delete(:location)
        expect(parsed_appointment[:friendly_location_name]).to eq(nil)
      end
    end

    context 'with CC appointment' do
      let(:appointment) { appointment_by_id(booked_cc_id) }

      it 'is set to cc location practice name' do
        expect(parsed_appointment[:friendly_location_name]).to eq('CC practice name')
      end

      it 'is set to nil when cc location practice name is absent' do
        appointment.delete(:extension)
        expect(parsed_appointment[:friendly_location_name]).to eq(nil)
      end
    end
  end
end
