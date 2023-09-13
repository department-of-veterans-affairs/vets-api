# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AppointmentsService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :jac) }
  let(:start_date) { Time.zone.parse('2021-06-04T04:00:00.000Z') }
  let(:end_date) { Time.zone.parse('2022-07-03T04:00:00.000Z') }
  let(:start_date2) { Time.zone.parse('2022-01-01T19:25:00Z') }
  let(:end_date2) { Time.zone.parse('2022-12-01T19:45:00Z') }
  let(:start_date3) { Time.zone.parse('2022-04-01T19:25:00Z') }
  let(:end_date3) { Time.zone.parse('2023-03-01T19:45:00Z') }
  let(:id) { '202006031600983000030800000000000000' }
  let(:appointment_id) { 123 }

  let(:appt_med) do
    { kind: 'clinic', service_category: [{ coding:
                 [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' }] }] }
  end
  let(:appt_non) do
    { kind: 'clinic', service_category: [{ coding:
                 [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'SERVICE CONNECTED' }] }],
      service_type: 'SERVICE CONNECTED', service_types: [{ coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'SERVICE CONNECTED' }] }] }
  end
  let(:appt_cnp) do
    { kind: 'clinic', service_category: [{ coding:
                 [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'COMPENSATION & PENSION' }] }] }
  end
  let(:appt_no_service_cat) { { kind: 'clinic' } }

  mock_facility = {
    test: 'test',
    timezone: {
      time_zone_id: 'America/New_York'
    }
  }

  mock_facility2 = {
    test: 'test',
    timezone: {
      time_zone_id: 'America/Denver'
    }
  }

  before do
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe '#post_appointment' do
    let(:va_proposed_clinic_request_body) do
      FactoryBot.build(:appointment_form_v2, :va_proposed_clinic, user:).attributes
    end

    let(:va_proposed_phone_request_body) do
      FactoryBot.build(:appointment_form_v2, :va_proposed_phone, user:).attributes
    end

    let(:va_booked_request_body) do
      FactoryBot.build(:appointment_form_v2, :va_booked, user:).attributes
    end

    let(:community_cares_request_body) do
      FactoryBot.build(:appointment_form_v2, :community_cares, user:).attributes
    end

    context 'when va appointment create request is valid' do
      # appointment created using the Jacqueline Morgan user

      it 'returns the created appointment - va - booked' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_JACQUELINE_M',
                         match_requests_on: %i[method path query]) do
          allow(Rails.logger).to receive(:info).at_least(:once)
          response = subject.post_appointment(va_booked_request_body)
          expect(response[:id]).to be_a(String)
        end
      end

      it 'returns the created appointment and logs data' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_and_logs_data',
                         match_requests_on: %i[method path query]) do
          allow(Rails.logger).to receive(:info).at_least(:once)
          response = subject.post_appointment(va_booked_request_body)
          expect(response[:id]).to be_a(String)
          expect(Rails.logger).to have_received(:info).with('VAOS telehealth atlas details',
                                                            any_args).at_least(:once)
        end
      end

      it 'returns the created appointment-va-proposed-clinic' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_va_proposed_clinic_200',
                         match_requests_on: %i[method path query]) do
          response = subject.post_appointment(va_proposed_clinic_request_body)
          expect(response[:id]).to eq('70065')
        end
      end
    end

    context 'when cc appointment create request is valid' do
      it 'returns the created appointment - cc - proposed' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_cc_200_2222022',
                         match_requests_on: %i[method path query]) do
          response = subject.post_appointment(community_cares_request_body)
          expect(response[:id]).to be_a(String)
        end
      end
    end

    context 'when the patientIcn is missing' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_400', match_requests_on: %i[method path query]) do
          expect { subject.post_appointment(community_cares_request_body) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when the patientIcn is missing on a direct scheduling submission' do
      it 'raises a backend exception and logs error details' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_400', match_requests_on: %i[method path query]) do
          allow(Rails.logger).to receive(:warn).at_least(:once)
          expect { subject.post_appointment(va_booked_request_body) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
          expect(Rails.logger).to have_received(:warn).with('Direct schedule submission error',
                                                            any_args).at_least(:once)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_500', match_requests_on: %i[method path query]) do
          expect { subject.post_appointment(community_cares_request_body) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_appointments' do
    context 'when requesting a list of appointments given a date range' do
      it 'returns a 200 status with list of appointments' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                         match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
          response = subject.get_appointments(start_date2, end_date2)
          expect(response[:data].size).to eq(16)
        end
      end

      it 'returns with list of appointments and appends local start time' do
        allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_facility).and_return(mock_facility2)
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                         match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
          response = subject.get_appointments(start_date2, end_date2)
          expect(response[:data][0][:local_start_time]).to eq('Thu, 02 Sep 2021 08:00:00 -0600')
          expect(response[:data][6][:requested_periods][0][:local_start_time]).to eq('Wed, 08 Sep 2021 06:00:00 -0600')
        end
      end

      it 'logs the VAOS telehealth atlas details of the returned appointments' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200_and_log_data',
                         allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
          allow(Rails.logger).to receive(:info).at_least(:once)

          response = subject.get_appointments(start_date3, end_date3)
          expect(response[:data].size).to eq(163)
          expect(Rails.logger).to have_received(:info).with('VAOS telehealth atlas details',
                                                            any_args).at_least(:once)
        end
      end
    end

    context 'when requesting a list of appointments given a date range and single status' do
      it 'returns a 200 status with list of appointments' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_single_status_200',
                         allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
          response = subject.get_appointments(start_date2, end_date2, 'proposed')
          expect(response[:data].size).to eq(5)
          expect(response[:data][0][:status]).to eq('proposed')
        end
      end
    end

    context 'when there are CnP and covid appointments in the list' do
      it 'changes the cancellable status to false for CnP and covid appointments only' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_cnp_covid',
                         allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
          response = subject.get_appointments(start_date2, end_date2, 'proposed')
          # non CnP or covid appointment, cancellable left as is
          expect(response[:data][0][:cancellable]).to eq(true)
          # CnP appointments, cancellable changed to false
          expect(response[:data][4][:cancellable]).to eq(false)
          # covid appointments, cancellable changed to false
          expect(response[:data][5][:cancellable]).to eq(false)
          expect(response[:data][6][:cancellable]).to eq(false)
          expect(response[:data][7][:cancellable]).to eq(false)
        end
      end
    end

    context 'when requesting a list of appointments given a date range and multiple statuses' do
      it 'returns a 200 status with list of appointments' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_multi_status_200',
                         allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
          response = subject.get_appointments(start_date2, end_date2, 'proposed,booked')
          expect(response[:data].size).to eq(2)
          expect(response[:data][0][:status]).to eq('proposed')
          expect(response[:data][1][:status]).to eq('booked')
        end
      end
    end

    context 'when requesting a list of appointments containing a non-Med non-CnP non-CC appointment' do
      it 'removes the service type(s) from only the non-med non-cnp non-covid appointment' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_non_med',
                         allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
          response = subject.get_appointments(start_date2, end_date2)
          expect(response[:data][0][:service_type]).to be_nil
          expect(response[:data][0][:service_types]).to be_nil
          expect(response[:data][1][:service_type]).not_to be_nil
          expect(response[:data][1][:service_types]).not_to be_nil
        end
      end
    end

    context 'when requesting a list of appointments containing a booked cerner appointment' do
      it 'sets the requested periods to nil' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200_booked_cerner',
                         allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
          response = subject.get_appointments(start_date2, end_date2)
          expect(response[:data][0][:requested_periods]).to be_nil
          expect(response[:data][1][:requested_periods]).not_to be_nil
        end
      end
    end

    context '400' do
      it 'raises a 400 error' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_400', match_requests_on: %i[method path query]) do
          expect { subject.get_appointments(start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context '401' do
      it 'raises a 401 error' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_401', match_requests_on: %i[method path query]) do
          expect { subject.get_appointments(start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context '403' do
      it 'raises a 403' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_403', match_requests_on: %i[method path query]) do
          expect { subject.get_appointments(start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_500', match_requests_on: %i[method path query]) do
          expect { subject.get_appointments(start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_most_recent_visited_clinic_appointment' do
    subject { instance_of_class.get_most_recent_visited_clinic_appointment }

    let(:instance_of_class) { described_class.new(user) }
    let(:mock_appointment_one) { double('Appointment', kind: 'clinic', start: '2022-12-01') }
    let(:mock_appointment_two) { double('Appointment', kind: 'telehealth', start: '2022-12-01T21:38:01.476Z') }
    let(:mock_appointment_three) { double('Appointment', kind: 'clinic', start: '2022-12-09T21:38:01.476Z') }

    context 'when appointments are available' do
      before do
        allow(instance_of_class).to receive(:get_appointments).and_return({ data: [mock_appointment_one,
                                                                                   mock_appointment_two,
                                                                                   mock_appointment_three] })
      end

      it 'returns the most recent clinic appointment' do
        expect(subject).to eq(mock_appointment_three)
      end
    end

    context 'when no appointments are available' do
      before do
        allow(instance_of_class).to receive(:get_appointments).and_return({ data: [] })
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when there are no clinic appointments' do
      before do
        allow(instance_of_class).to receive(:get_appointments).and_return({ data: [mock_appointment_two] })
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when the second interval search returns an appointment' do
      before do
        allow(instance_of_class).to receive(:get_appointments).and_return({ data: [mock_appointment_two] },
                                                                          { data: [mock_appointment_one,
                                                                                   mock_appointment_two,
                                                                                   mock_appointment_three] })
      end

      it 'returns the most recent clinic appointment' do
        expect(subject).to eq(mock_appointment_three)
      end
    end
  end

  describe '#get_appointment' do
    context 'with an appointment' do
      context 'with Jacqueline Morgan' do
        it 'returns a proposed appointment' do
          allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_facility).and_return(mock_facility)
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_with_facility_200',
                           match_requests_on: %i[method path query]) do
            response = subject.get_appointment('70060')
            expect(response[:id]).to eq('70060')
            expect(response[:kind]).to eq('clinic')
            expect(response[:status]).to eq('proposed')
            expect(response[:requested_periods][0][:local_start_time]).to eq('Sun, 19 Dec 2021 19:00:00 -0500')
          end
        end
      end
    end

    context 'when requesting a booked cerner appointment' do
      let(:user) { build(:user, :vaos) }

      it 'returns a booked cerner appointment with the requested periods set to nil' do
        VCR.use_cassette('vaos/v2/appointments/get_appointment_200_booked_cerner',
                         match_requests_on: %i[method path query]) do
          resp = subject.get_appointment('180402')
          expect(resp[:id]).to eq('180402')
          expect(resp[:requested_periods]).to be_nil
        end
      end
    end

    context 'when requesting a CnP appointment' do
      let(:user) { build(:user, :vaos) }

      it 'sets the cancellable attribute to false' do
        VCR.use_cassette('vaos/v2/appointments/get_appointment_200_CnP',
                         match_requests_on: %i[method path query]) do
          response = subject.get_appointment('159472')
          expect(response[:cancellable]).to eq(false)
        end
      end
    end

    context 'when requesting a non-Med non-CnP appointment' do
      let(:user) { build(:user, :vaos) }

      it 'removes the appointments service type and service types attributes' do
        VCR.use_cassette('vaos/v2/appointments/get_appointment_200_non_med',
                         match_requests_on: %i[method path query]) do
          response = subject.get_appointment('159472')
          expect(response[:service_type]).to be_nil
          expect(response[:service_types]).to be_nil
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/get_appointment_500', match_requests_on: %i[method path query]) do
          expect { subject.get_appointment('00000') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#cancel_appointment' do
    context 'when the upstream server attemps to cancel an appointment' do
      context 'with Jaqueline Morgan' do
        it 'returns a cancelled status and the cancelled appointment information' do
          VCR.use_cassette('vaos/v2/appointments/cancel_appointments_200', match_requests_on: %i[method path query]) do
            response = subject.update_appointment('70060', 'cancelled')
            expect(response.status).to eq('cancelled')
          end
        end
      end

      it 'returns a 400 when the appointment is not cancellable' do
        VCR.use_cassette('vaos/v2/appointments/cancel_appointment_400', match_requests_on: %i[method path query]) do
          expect { subject.update_appointment('42081', 'cancelled') }
            .to raise_error do |error|
            expect(error).to be_a(Common::Exceptions::BackendServiceException)
            expect(error.status_code).to eq(400)
          end
        end
      end
    end

    context 'when there is a server error in updating an appointment' do
      it 'throws a BackendServiceException' do
        VCR.use_cassette('vaos/v2/appointments/cancel_appointment_500', match_requests_on: %i[method path query]) do
          expect { subject.update_appointment('35952', 'cancelled') }
            .to raise_error do |error|
            expect(error).to be_a(Common::Exceptions::BackendServiceException)
            expect(error.status_code).to eq(502)
          end
        end
      end
    end
  end

  describe '#get_facility_timezone' do
    let(:facility_location_id) { '983' }
    let(:facility_error_msg) { 'Error fetching facility details' }

    context 'with a facility location id' do
      it 'returns the facility timezone' do
        allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_facility).and_return(mock_facility)
        timezone = subject.send(:get_facility_timezone, facility_location_id)
        expect(timezone).to eq('America/New_York')
      end
    end

    context 'with an internal server error from the facilities call' do
      it 'returns nil for the timezone' do
        allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_facility).and_return(facility_error_msg)
        timezone = subject.send(:get_facility_timezone, facility_location_id)
        expect(timezone).to eq(nil)
      end
    end
  end

  describe '#convert_utc_to_local_time' do
    let(:start_datetime) { '2021-09-02T14:00:00Z'.to_datetime }

    context 'with a date and timezone' do
      it 'converts UTC to local time' do
        local_time = subject.send(:convert_utc_to_local_time, start_datetime, 'America/New_York')
        expect(local_time.to_s).to eq(start_datetime.to_time.utc.in_time_zone('America/New_York').to_datetime.to_s)
      end
    end

    context 'with a date and no timezone' do
      it 'returns warning message' do
        local_time = subject.send(:convert_utc_to_local_time, start_datetime, nil)
        expect(local_time.to_s).to eq('Unable to convert UTC to local time')
      end
    end

    context 'with a nil date' do
      it 'throws a ParameterMissing exception' do
        expect do
          subject.send(:convert_utc_to_local_time, nil, 'America/New_York')
        end.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end
  end

  describe '#codes' do
    context 'when nil is passed in' do
      it 'returns an empty array' do
        expect(subject.send(:codes, nil)).to eq([])
      end
    end

    context 'when no codable concept code is present' do
      it 'returns an empty array' do
        x = [{ coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', display: 'REGULAR' }],
               text: 'REGULAR' }]
        expect(subject.send(:codes, x)).to eq([])
      end
    end

    context 'when a codable concept code is present' do
      it 'returns an array of codable concept codes' do
        x = [{ coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' }],
               text: 'REGULAR' }]
        expect(subject.send(:codes, x)).to eq(['REGULAR'])
      end
    end

    context 'when multiple codable concept codes are present' do
      it 'returns an array of codable concept codes' do
        x = [{ coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' },
                        { system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'TELEHEALTH' }],
               text: 'REGULAR' }]
        expect(subject.send(:codes, x)).to eq(%w[REGULAR TELEHEALTH])
      end
    end

    context 'when multiple codable concepts with single codes are present' do
      it 'returns an array of codable concept codes' do
        x = [{ coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' }],
               text: 'REGULAR' },
             { coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'TELEHEALTH' }],
               text: 'TELEHEALTH' }]
        expect(subject.send(:codes, x)).to eq(%w[REGULAR TELEHEALTH])
      end
    end
  end

  describe '#medical?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:medical?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true for medical appointments' do
      expect(subject.send(:medical?, appt_med)).to eq(true)
    end

    it 'returns false for non-medical appointments' do
      expect(subject.send(:medical?, appt_non)).to eq(false)
    end
  end

  describe '#no_service_cat?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:no_service_cat?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true for appointments without a service category' do
      expect(subject.send(:no_service_cat?, appt_no_service_cat)).to eq(true)
    end

    it 'returns false for appointments with a service category' do
      expect(subject.send(:no_service_cat?, appt_non)).to eq(false)
    end
  end

  describe '#cnp?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:cnp?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true for compensation and pension appointments' do
      expect(subject.send(:cnp?, appt_cnp)).to eq(true)
    end

    it 'returns false for non compensation and pension appointments' do
      expect(subject.send(:cnp?, appt_non)).to eq(false)
    end
  end

  describe '#remove_service_type' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:remove_service_type, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'Modifies the appointment with service type(s) removed from appointment' do
      expect { subject.send(:remove_service_type, appt_non) }.to change(appt_non, :keys)
        .from(%i[kind service_category service_type service_types])
        .to(%i[kind service_category])
    end
  end

  describe '#cerner?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:cerner?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true when the appointment is cerner' do
      appt = {
        identifier: [
          {
            system: 'urn:va.gov:masv2:cerner:appointment',
            value: 'Appointment/52499028'
          }
        ]
      }

      expect(subject.send(:cerner?, appt)).to eq(true)
    end

    it 'returns false when the appointment is not cerner' do
      appt = {
        identifier: [
          {
            system: 'someother system',
            value: 'appointment/1'
          }
        ]
      }

      expect(subject.send(:cerner?, appt)).to eq(false)
    end

    it 'returns true when at least one identifier is cerner' do
      appt = {
        identifier: [
          {
            system: 'someother system',
            value: 'appointment/1'
          },
          {
            system: 'urn:va.gov:masv2:cerner:appointment',
            value: 'Appointment/52499028'
          }
        ]
      }

      expect(subject.send(:cerner?, appt)).to eq(true)
    end

    it 'returns false when the appointment does not contain identifier(s)' do
      appt = {}

      expect(subject.send(:cerner?, appt)).to eq(false)
    end
  end

  describe '#booked?' do
    it 'returns true when the appointment status is booked' do
      appt = {
        status: 'booked'
      }

      expect(subject.send(:booked?, appt)).to eq(true)
    end

    it 'returns false when the appointment status is not booked' do
      appt = {
        status: 'cancelled'
      }

      expect(subject.send(:booked?, appt)).to eq(false)
    end

    it 'returns false when the appointment does not contain status' do
      appt = {}

      expect(subject.send(:booked?, appt)).to eq(false)
    end

    it 'raises an ArgumentError when the appointment nil' do
      expect { subject.send(:booked?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end
  end
end
