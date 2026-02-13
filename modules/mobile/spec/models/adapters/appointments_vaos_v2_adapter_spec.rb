# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::VAOSV2Appointments, :aggregate_failures do
  let(:appointment_fixtures) do
    Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'VAOS_v2_appointments.json').read
  end
  let(:raw_data) { JSON.parse(appointment_fixtures, symbolize_names: true) }

  let(:booked_va_id) { '121134' }
  let(:booked_cc_id) { '72106' }
  let(:proposed_va_id) { '50956' }
  let(:proposed_cc_id) { '72105' }
  let(:cancelled_va_id) { '121133' }
  let(:cancelled_proposed_va_id) { '53241' }
  let(:phone_va_id) { '53352' }
  let(:home_va_mobile_any_id) { '50094' }
  let(:atlas_va_id) { '50095' }
  let(:home_mobile_any_gfe_id) { '50096' }
  let(:home_va_mobile_any_group_id) { '50098' }
  let(:home_va_adhoc_id) { '50099' }
  let(:home_mobile_gfe_id) { '50100' }
  let(:past_request_date_appt_id) { '53360' }
  let(:future_request_date_appt_id) { '53359' }
  let(:telehealth_onsite_id) { '50097' }
  let(:missing_vvs_kind_id) { '50101' }
  let(:cerner_va_id) { 'CERN129377263' }

  def appointment_data(index = nil)
    appts = index ? raw_data[index] : raw_data
    Array.wrap(appts).map { |appt| OpenStruct.new(appt) }
  end

  def appointment_by_id(id, overrides: {}, without: [])
    appointment = raw_data.find { |appt| appt[:id] == id }
    appointment.merge!(overrides) if overrides.any?
    without.each do |property|
      if property.is_a?(Hash)
        appointment.dig(*property[:at]).delete(property[:key])
      else
        appointment.delete(property)
      end
    end
    subject.parse(Array.wrap(appointment)).first
  end

  before do
    Timecop.freeze(Time.zone.parse('2022-08-25T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  it 'returns an empty array when provided nil' do
    expect(subject.parse(nil)).to eq([])
  end

  it 'returns a list of Mobile::V0::Appointments at the expected size' do
    adapted_appointments = subject.parse(appointment_data)
    expect(adapted_appointments.size).to eq(18)
    expect(adapted_appointments.map(&:class).uniq).to match_array(Mobile::V0::Appointment)
  end

  it 'has expected fields' do
    appt = appointment_by_id(booked_va_id)
    expect(appt.as_json).to eq({
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
                                 'friendly_location_name' => 'Friendly Name Optometry',
                                 'service_category_name' => nil,
                                 'show_schedule_link' => nil,
                                 'is_cerner' => nil,
                                 'avs_pdf' => nil,
                                 'avs_error' => nil
                               })
  end

  describe 'passthrough values' do
    it 'sets them to the provided values without modification' do
      overrides = {
        ien: 'IEN 1',
        patient_comments: 'COMMENT',
        physical_location: 'NYC',
        reason_for_appointment: 'REASON',
        preferred_times_for_phone_call: 'WHENEVER'
      }
      appt = appointment_by_id(booked_va_id, overrides:)
      expect(appt.id).to eq(booked_va_id)
      expect(appt.appointment_ien).to eq('IEN 1')
      expect(appt.comment).to eq('COMMENT')
      expect(appt.healthcare_service).to be_nil # always nil
      expect(appt.physical_location).to eq('NYC')
      expect(appt.minutes_duration).to eq(30)
      expect(appt.reason).to eq('REASON')
      expect(appt.best_time_to_call).to eq('WHENEVER')
    end
  end

  describe 'appointment_type' do
    it 'sets va requests to VA' do
      appt = appointment_by_id(proposed_va_id)
      expect(appt.appointment_type).to eq('VA')
    end

    it 'sets phone appointments to VA' do
      appt = appointment_by_id(phone_va_id)
      expect(appt.appointment_type).to eq('VA')
    end

    it 'sets clinic appointments to VA' do
      appt = appointment_by_id(booked_va_id)
      expect(appt.appointment_type).to eq('VA')
    end

    it 'sets CC appointments to COMMUNITY_CARE' do
      appt = appointment_by_id(booked_cc_id)
      expect(appt.appointment_type).to eq('COMMUNITY_CARE')
    end

    context 'telehealth' do
      it 'sets atlas appointments to VA_VIDEO_CONNECT_ATLAS' do
        appt = appointment_by_id(atlas_va_id)
        expect(appt.appointment_type).to eq('VA_VIDEO_CONNECT_ATLAS')
      end

      it 'sets GFE MOBILE_ANY appointments to VA_VIDEO_CONNECT_GFE' do
        appt = appointment_by_id(home_mobile_any_gfe_id)
        expect(appt.appointment_type).to eq('VA_VIDEO_CONNECT_GFE')
      end

      it 'sets GFE MOBILE_GFE appointments to VA_VIDEO_CONNECT_GFE' do
        appt = appointment_by_id(home_mobile_gfe_id)
        expect(appt.appointment_type).to eq('VA_VIDEO_CONNECT_GFE')
      end

      it 'sets home non-GFE MOBILE_ANY appointments to VA_VIDEO_CONNECT_HOME' do
        appt = appointment_by_id(home_va_mobile_any_id)
        expect(appt.appointment_type).to eq('VA_VIDEO_CONNECT_HOME')
      end

      it 'sets home non-GFE MOBILE_ANY_GROUP appointments to VA_VIDEO_CONNECT_HOME' do
        appt = appointment_by_id(home_va_mobile_any_group_id)
        expect(appt.appointment_type).to eq('VA_VIDEO_CONNECT_HOME')
      end

      it 'sets home non-GFE ADHOC appointments to VA_VIDEO_CONNECT_HOME' do
        appt = appointment_by_id(home_va_adhoc_id)
        expect(appt.appointment_type).to eq('VA_VIDEO_CONNECT_HOME')
      end

      it 'sets onsite appointments to VA_VIDEO_CONNECT_ONSITE' do
        appt = appointment_by_id(telehealth_onsite_id)
        expect(appt.appointment_type).to eq('VA_VIDEO_CONNECT_ONSITE')
      end

      it 'sets telehealth appointments without vvs_kind to VA when vvs_vista_video_appt is missing' do
        appt = appointment_by_id(missing_vvs_kind_id)
        expect(appt.appointment_type).to eq('VA')
      end

      it 'sets telehealth appointments without vvs_kind to VA when vvs_vista_video_appt is false' do
        appt = appointment_by_id(missing_vvs_kind_id, overrides: { extension: { vvs_vista_video_appt: false } })
        expect(appt.appointment_type).to eq('VA')
      end

      it 'sets telehealth appointments without vvs_kind to VA_VIDEO_CONNECT_HOME when vvs_vista_video_appt is true' do
        appt = appointment_by_id(missing_vvs_kind_id, overrides: { extension: { vvs_vista_video_appt: true } })
        expect(appt.appointment_type).to eq('VA_VIDEO_CONNECT_HOME')
      end
    end
  end

  describe 'cancel_id' do
    context 'when telehealth appointment and cancellable is true' do
      it 'is nil' do
        expect(appointment_by_id(home_va_mobile_any_id).cancel_id).to be_nil
      end
    end

    context 'when not telehealth appointment and cancellable is false' do
      it 'is nil' do
        appt = appointment_by_id(home_va_mobile_any_id, overrides: { cancellable: false })
        expect(appt.cancel_id).to be_nil
      end
    end

    context 'when not telehealth appointment and cancellable is true' do
      it 'is the appointment id' do
        appt = appointment_by_id(future_request_date_appt_id)
        expect(appt.cancel_id).to eq(future_request_date_appt_id)
      end
    end
  end

  describe 'facility_id and sta6aid' do
    it 'are set to the result of convert_from_non_prod_id' do
      # this method is tested in the appointment model and doesn't need to be retested here
      expect(Mobile::V0::Appointment).to receive(:convert_from_non_prod_id!).and_return('anything')
      appt = appointment_by_id(home_va_mobile_any_id)
      expect(appt.facility_id).to eq('anything')
      expect(appt.sta6aid).to eq('anything')
    end
  end

  describe 'healthcare provider' do
    let(:practitioner_list) do
      [
        {
          identifier: [{ system: 'dfn-983', value: '520647609' }],
          name: { family: 'ENGHAUSER', given: ['MATTHEW'] },
          practice_name: 'Site #983'
        },
        {
          identifier: [{ system: 'dfn-983', value: '520647609' }],
          name: { family: 'FORTH', given: ['SALLY'] },
          practice_name: 'Site #983'
        }
      ]
    end

    it 'uses the first practitioner name in the list' do
      appt = appointment_by_id(
        booked_va_id,
        overrides: { preferred_provider_name: 'Dr. Hauser', practitioners: practitioner_list }
      )
      expect(appt.healthcare_provider).to eq('MATTHEW ENGHAUSER')
    end

    it 'uses the preferred_provider_name if no practitioner list exists' do
      appt = appointment_by_id(booked_va_id, overrides: { preferred_provider_name: 'Dr. Hauser' })
      expect(appt.healthcare_provider).to eq('Dr. Hauser')
    end

    it 'converts not found message to nil' do
      appt = appointment_by_id(
        booked_va_id,
        overrides: { preferred_provider_name: VAOS::V2::AppointmentProviderName::NPI_NOT_FOUND_MSG }
      )
      expect(appt.healthcare_provider).to be_nil
    end

    it 'uses the practitioners list in favor of the not found message' do
      appt = appointment_by_id(
        booked_va_id,
        overrides: {
          preferred_provider_name: VAOS::V2::AppointmentProviderName::NPI_NOT_FOUND_MSG,
          practitioners: practitioner_list
        }
      )
      expect(appt.healthcare_provider).to eq('MATTHEW ENGHAUSER')
    end
  end

  describe 'location' do
    context 'with a cc appointment request' do
      let(:practitioner_list) do
        [
          {
            identifier: [
              {
                system: 'http://hl7.org/fhir/sid/us-npi',
                value: '1780671644'
              }
            ],
            address: {
              type: 'physical',
              line: [
                '161 MADISON AVE STE 7SW'
              ],
              city: 'NEW YORK',
              state: 'NY',
              postal_code: '10016-5448',
              text: '161 MADISON AVE STE 7SW,NEW YORK,NY,10016-5448'
            }
          }
        ]
      end

      it 'sets location from practitioners list' do
        proposed_cc = appointment_by_id(proposed_cc_id, overrides: { practitioners: practitioner_list })
        expect(proposed_cc.location.to_h).to eq({
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
        booked_cc = appointment_by_id(booked_cc_id)
        expect(booked_cc.location.to_h).to eq(
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
        atlas_va = appointment_by_id(atlas_va_id)
        expect(atlas_va.location.to_h).to eq(
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
        booked_va = appointment_by_id(booked_va_id)
        expect(booked_va.location.to_h).to eq(
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

  describe 'phone_only' do
    context 'when appointment kind is phone' do
      it 'is set to true' do
        appt = appointment_by_id(booked_va_id, overrides: { kind: 'phone' })
        expect(appt.phone_only).to be(true)
      end
    end

    context 'when appointment kind is not phone' do
      it 'is set to false' do
        appt = appointment_by_id(booked_va_id)
        expect(appt.phone_only).to be(false)
      end
    end
  end

  describe 'start_date_utc' do
    context 'when start is present' do
      it 'converts start to datetime' do
        appt = appointment_by_id(booked_va_id)
        expect(appt.start_date_utc).to eq('2018-03-07T07:00:00+00:00'.to_datetime)
      end
    end

    context 'when start is nil' do
      context 'and request periods that are in the future' do
        it 'sets start date to earliest date in the future' do
          future_request_date_appt = appointment_by_id(future_request_date_appt_id)
          expect(future_request_date_appt.start_date_utc).to eq('2022-08-27T12:00:00Z'.to_datetime)
        end
      end

      context 'request periods that are in the past' do
        it 'sets start date to earliest date' do
          past_request_date_appt = appointment_by_id(past_request_date_appt_id)
          expect(past_request_date_appt.start_date_utc).to eq('2021-08-20T12:00:00Z')
        end
      end
    end
  end

  describe 'start_date_local' do
    context 'when local_start_time is present and parseable' do
      it 'converts local_start_time to datetime' do
        appt = appointment_by_id(
          booked_va_id,
          overrides: { local_start_time: '2019-04-15T009:00:00Z' }
        )
        expect(appt.start_date_local).to eq('2019-04-15T09:00:00+00:00'.to_datetime)
      end
    end

    context 'when local_start_time is missing or unparseable' do
      it 'falls back to using the start_date_utc adjusted to the timezone' do
        # local_start_time is not present in provided test data
        appt = appointment_by_id(booked_va_id)
        expect(appt.start_date_local).to eq('2018-03-07T15:00:00+08:00'.to_datetime)
      end
    end
  end

  describe 'proposed_times' do
    context 'when requested_periods are present' do
      it 'forms a list of dates based on requested_periods' do
        appt = appointment_by_id(future_request_date_appt_id)
        expect(appt.proposed_times).to eq([{ date: '08/20/2022', time: 'PM' },
                                           { date: '08/27/2022', time: 'PM' },
                                           { date: '10/03/2022', time: 'PM' }])
      end
    end

    context 'when requested_periods are not present' do
      it 'is set to nil when there are no requested periods' do
        # booked appointments never have requested periods
        appt = appointment_by_id(booked_va_id)
        expect(appt.proposed_times).to be_nil
      end
    end
  end

  describe 'time_zone' do
    context 'when timezone is present in data' do
      it 'falls back to hardcoded timezone lookup' do
        appt = appointment_by_id(booked_va_id)
        expect(appt.time_zone).to eq('America/Denver')
      end
    end

    context 'when timezone is not present in data' do
      it 'falls back to hardcoded timezone lookup' do
        # overriding location id to prevent false positives
        no_timezone_appt = appointment_by_id(
          booked_va_id,
          overrides: { location_id: '358' },
          without: [key: :time_zone, at: :location]
        )
        expect(no_timezone_appt.time_zone).to eq('Asia/Manila')
      end
    end
  end

  describe 'status' do
    context 'with known status' do
      it 'converts status to appropriate text' do
        arrived_appt = appointment_by_id(booked_va_id, overrides: { status: 'arrived' })
        expect(arrived_appt.status).to eq('BOOKED')
      end
    end

    context 'with unknown status' do
      it 'raises an error' do
        expect { appointment_by_id(booked_va_id, overrides: { status: 'unknown' }) }.to raise_error(Dry::Struct::Error)
      end
    end
  end

  describe 'status_detail' do
    context 'when no cancellation reason is provided and appointment is cancelled' do
      it 'sets to default message' do
        appt = appointment_by_id(booked_va_id, overrides: { status: 'cancelled' })
        expect(appt.status_detail).to eq('CANCELLED BY CLINIC')
      end
    end

    context 'when no cancellation reason is provided and appointment is not cancelled' do
      it 'returns nil' do
        appt = appointment_by_id(booked_va_id)
        expect(appt.status_detail).to be_nil
      end
    end

    context 'when known cancellation reason is provided' do
      it 'returns appropriate text' do
        appt = appointment_by_id(cancelled_proposed_va_id)
        expect(appt.status_detail).to eq('CANCELLED BY CLINIC')
      end
    end

    context 'when unknown cancellation reason is provided' do
      it 'returns nil' do
        appt = appointment_by_id(cancelled_proposed_va_id, overrides: { cancellation_reason: nil })
        expect(appt.status_detail).to eq('CANCELLED BY CLINIC')
      end
    end
  end

  describe 'vetext_id' do
    it 'combines the facility id and a timestamp' do
      appt = appointment_by_id(booked_cc_id)
      expect(appt.vetext_id).to eq('552;3220111.08')
    end
  end

  describe 'is_covid_vaccine' do
    it 'is true when service type is covid' do
      appt = appointment_by_id(booked_va_id, overrides: { service_type: 'covid' })
      expect(appt.is_covid_vaccine).to be(true)
    end

    it 'is false when service type is not covid' do
      appt = appointment_by_id(booked_va_id)
      expect(appt.is_covid_vaccine).to be(false)
    end
  end

  describe 'patient_phone_number' do
    let(:appt_with_phone) do
      appointment_by_id(
        atlas_va_id, overrides: { contact: { telecom: [{ type: 'phone', value: phone_number }] } }
      )
    end

    context 'with area code parentheses' do
      let(:phone_number) { '(480)-293-1922' }

      it 'formats to all dashes' do
        expect(appt_with_phone.patient_phone_number).to eq('480-293-1922')
      end
    end

    context 'formats to all dashes' do
      let(:phone_number) { '(480) 293-1922' }

      it 'formats phone number' do
        expect(appt_with_phone.patient_phone_number).to eq('480-293-1922')
      end
    end

    context 'with no delimiters' do
      let(:phone_number) { '4802931922' }

      it 'formats to all dashes' do
        expect(appt_with_phone.patient_phone_number).to eq('480-293-1922')
      end
    end

    context 'dash separated' do
      let(:phone_number) { '480-293-1922' }

      it 'uses the number without change' do
        expect(appt_with_phone.patient_phone_number).to eq('480-293-1922')
      end
    end

    context 'when no phone number is present' do
      let(:phone_number) { nil }

      it 'is set to nil' do
        expect(appt_with_phone.patient_phone_number).to be_nil
      end
    end
  end

  describe 'is_pending' do
    it 'is true for appointment requests' do
      appt = appointment_by_id(proposed_va_id)
      expect(appt.is_pending).to be(true)
    end

    it 'is false for confirmed appointments' do
      appt = appointment_by_id(booked_va_id)
      expect(appt.is_pending).to be(false)
    end
  end

  describe 'patient_email' do
    context 'when contact info is not present' do
      it 'is nil' do
        appt = appointment_by_id(proposed_cc_id, without: [:contact])
        expect(appt.patient_email).to be_nil
      end
    end

    context 'when contact info is present' do
      it 'is set from contact data' do
        appt = appointment_by_id(proposed_cc_id)
        expect(appt.patient_email).to eq('Aarathi.poldass@va.gov')
      end
    end
  end

  describe 'friendly_location_name' do
    context 'with VA appointment' do
      it 'is set to service name value if it exists' do
        appt = appointment_by_id(booked_va_id)
        expect(appt.friendly_location_name).to eq('Friendly Name Optometry')
      end

      it 'is set to location name value if service_name does not exist' do
        appt = appointment_by_id(booked_va_id, without: [:service_name])
        expect(appt.friendly_location_name).to eq('Cheyenne VA Medical Center')
      end

      it 'is set to nil when location name and service name are absent' do
        appt = appointment_by_id(booked_va_id, without: %i[location service_name])
        expect(appt.friendly_location_name).to be_nil
      end
    end

    context 'with VA proposed appointment' do
      it 'is set to service name value if it exists' do
        appt = appointment_by_id(proposed_va_id)
        expect(appt.friendly_location_name).to eq('Friendly Name Optometry')
      end

      it 'is set to location name value if service_name does not exist' do
        appt = appointment_by_id(proposed_va_id, without: [:service_name])
        expect(appt.friendly_location_name).to eq('Cheyenne VA Medical Center')
      end

      it 'is set to nil when location name and service name are absent' do
        appt = appointment_by_id(proposed_va_id, without: %i[location service_name])
        expect(appt.friendly_location_name).to be_nil
      end
    end

    context 'with CC appointment request' do
      it 'is set to location name' do
        appt = appointment_by_id(proposed_cc_id)
        expect(appt.friendly_location_name).to eq('Cheyenne VA Medical Center')
      end

      it 'is set to nil when CC location name is absent' do
        appt = appointment_by_id(proposed_cc_id, without: [:location])
        expect(appt.friendly_location_name).to be_nil
      end
    end

    context 'with CC appointment' do
      it 'is set to cc location practice name' do
        appt = appointment_by_id(booked_cc_id)
        expect(appt.friendly_location_name).to eq('CC practice name')
      end

      it 'is set to nil when cc location practice name is absent' do
        appt = appointment_by_id(booked_cc_id, without: [:extension])
        expect(appt.friendly_location_name).to be_nil
      end
    end
  end

  describe 'service_category_name' do
    context 'when service category is present' do
      it 'is set to the first service category text' do
        # none of the fixture data contains this
        appt = appointment_by_id(booked_cc_id, overrides: { service_category: [text: 'therapy'] })
        expect(appt.service_category_name).to eq('therapy')
      end
    end

    context 'when service category is not present' do
      it 'is set to nil' do
        appt = appointment_by_id(booked_cc_id)
        expect(appt.service_category_name).to be_nil
      end
    end
  end

  describe 'show_schedule_link' do
    context 'when appointment is cancelled' do
      it 'passes through the proper boolean value' do
        appt = appointment_by_id(cancelled_va_id)
        expect(appt.show_schedule_link).to be(true)
      end
    end

    context 'when appointment has a different status' do
      it 'does not contain the show_schedule_link field' do
        appt = appointment_by_id(booked_va_id)
        expect(appt.show_schedule_link).to be_nil
      end
    end
  end

  describe 'is_cerner' do
    it 'passes through the proper boolean value' do
      appt = appointment_by_id(booked_va_id)
      expect(appt.is_cerner).to be_nil
      appt = appointment_by_id(cerner_va_id)
      expect(appt.is_cerner).to be(true)
    end
  end

  describe 'avs_pdf' do
    let(:avs_pdf) do
      {
        appt_id: '12345',
        id: '15249638961',
        name: 'Ambulatory Visit Summary',
        loinc_codes: %w[4189669 96345-4],
        note_type: 'ambulatory_patient_summary',
        content_type: 'application/pdf',
        binary: 'JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9TdWJ0e'
      }
    end

    it 'passes through the proper boolean value' do
      appt = appointment_by_id(booked_va_id)
      expect(appt.avs_pdf).to be_nil
      appt = appointment_by_id(cerner_va_id)
      expect(appt.avs_pdf.length).to eq(1)
      expect(appt.avs_pdf[0].to_h).to eq(avs_pdf)
    end
  end

  describe 'avs_error' do
    it 'passes through the proper error message' do
      appt = appointment_by_id(booked_va_id)
      expect(appt.avs_error).to be_nil
      appt = appointment_by_id(cerner_va_id, overrides: { avs_error: 'Error retrieving AVS' })
      expect(appt.avs_error).to eq('Error retrieving AVS')
    end
  end
end
