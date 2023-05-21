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

  mock_facility = {
    test: 'test',
    timezone: {
      zone_id: 'America/New_York'
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
          expect(Rails.logger).to have_received(:info).with('VAOS appointment service category and type',
                                                            any_args).at_least(:once)
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

      it 'logs the service categories of the returned appointments' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200_and_log_data',
                         allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
          allow(Rails.logger).to receive(:info).at_least(:once)

          telehealth_log_body = '{"VAOSServiceTypesAndCategory":{"vaos_appointment_kind":"telehealth",' \
                                '"vaos_service_type":"ServiceTypeNotFound","vaos_service_types":' \
                                '"ServiceTypesNotFound","vaos_service_category":"ServiceCategoryNotFound"}}'

          clinic_log_body = '{"VAOSServiceTypesAndCategory":{"vaos_appointment_kind":"clinic",' \
                            '"vaos_service_type":"optometry","vaos_service_types":"optometry",' \
                            '"vaos_service_category":"REGULAR"}}'

          response = subject.get_appointments(start_date3, end_date3)
          expect(response[:data].size).to eq(163)
          expect(Rails.logger).to have_received(:info).with('VAOS appointment service category and type',
                                                            telehealth_log_body).at_least(:once)
          expect(Rails.logger).to have_received(:info).with('VAOS appointment service category and type',
                                                            clinic_log_body).at_least(:once)
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

  describe '#get_appointment' do
    context 'with an appointment' do
      context 'with Jacqueline Morgan' do
        it 'returns a proposed appointment' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_with_facility_200',
                           match_requests_on: %i[method path query]) do
            response = subject.get_appointment('70060')
            expect(response[:id]).to eq('70060')
            expect(response[:kind]).to eq('clinic')
            expect(response[:status]).to eq('proposed')
          end
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
      it 'does not convert UTC to local time' do
        local_time = subject.send(:convert_utc_to_local_time, start_datetime, nil)
        expect(local_time.to_s).to eq(start_datetime.to_s)
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
end
