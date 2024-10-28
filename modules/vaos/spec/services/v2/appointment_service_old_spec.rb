# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AppointmentsService do
  include ActiveSupport::Testing::TimeHelpers

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
  let(:provider_name) { 'TEST PROVIDER NAME' }

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
    Flipper.enable_actor(:appointments_consolidation, user)
    Flipper.disable(:va_online_scheduling_use_vpg)
    Flipper.disable(:va_online_scheduling_enable_OH_requests)
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

    context 'using VAOS' do
      context 'when va appointment create request is valid' do
        # appointment created using the Jacqueline Morgan user

        it 'returns the created appointment - va - booked' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_JACQUELINE_M',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                             match_requests_on: %i[method path query]) do
              VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200',
                               match_requests_on: %i[method path query]) do
                allow(Rails.logger).to receive(:info).at_least(:once)
                response = subject.post_appointment(va_booked_request_body)
                expect(response[:id]).to be_a(String)
                expect(response[:local_start_time])
                  .to eq(DateTime.parse('2022-11-30T13:45:00-07:00'))
              end
            end
          end
        end

        it 'returns the created appointment and logs data' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_and_logs_data',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                             match_requests_on: %i[method path query]) do
              VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200',
                               match_requests_on: %i[method path query]) do
                response = subject.post_appointment(va_booked_request_body)
                expect(response[:id]).to be_a(String)
                expect(response[:local_start_time])
                  .to eq(DateTime.parse('2022-11-30T13:45:00-07:00'))
              end
            end
          end
        end

        it 'returns the created appointment-va-proposed-clinic' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_proposed_clinic_200',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                             match_requests_on: %i[method path query]) do
              VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200',
                               match_requests_on: %i[method path query]) do
                response = subject.post_appointment(va_proposed_clinic_request_body)
                expect(response[:id]).to eq('70065')
              end
            end
          end
        end
      end

      context 'when cc appointment create request is valid' do
        it 'returns the created appointment - cc - proposed' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_cc_200_2222022',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                             match_requests_on: %i[method path query]) do
              response = subject.post_appointment(community_cares_request_body)
              expect(response[:id]).to be_a(String)
              expect(response.dig(:requested_periods, 0, :local_start_time))
                .to eq(DateTime.parse('2021-06-15T06:00:00-06:00'))
            end
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
  end

  describe '#get_appointments' do
    context 'using VAOS' do
      before do
        Timecop.freeze(DateTime.parse('2021-09-02T14:00:00Z'))
      end

      after do
        Timecop.unfreeze
      end

      context 'when requesting a list of appointments given a date range' do
        it 'returns a 200 status with list of appointments' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                           match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
            response = subject.get_appointments(start_date2, end_date2)
            expect(response[:data].size).to eq(16)
          end
        end

        it 'returns with list of appointments and appends local start time' do
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility!).and_return(mock_facility2)
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                           match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
            response = subject.get_appointments(start_date2, end_date2)
            expect(response[:data][0][:local_start_time]).to eq('Thu, 02 Sep 2021 08:00:00 -0600')
            expect(response[:data][6][:requested_periods][0][:local_start_time]).to eq(
              'Wed, 08 Sep 2021 06:00:00 -0600'
            )
          end
        end
      end

      context 'when partial success is returned and failures are returned with ICNs' do
        before do
          allow_any_instance_of(VAOS::V2::AppointmentProviderName)
            .to receive(:form_names_from_appointment_practitioners_list)
            .and_return(nil)
        end

        it 'does not anonymizes the ICNs in the response' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200_and_log_data',
                           match_requests_on: %i[method path query]) do
            response = subject.get_appointments(start_date3, end_date3)
            expect(response.dig(:meta, :failures).to_json).to match(/\d{10}V\d{6}/)
          end
        end

        it 'logs the failures and anonymizes the ICNs sent to the log' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200_and_log_data',
                           match_requests_on: %i[method path query]) do
            expected_msg = 'VAOS::V2::AppointmentService#get_appointments has response errors. : ' \
                           '{:failures=>"[{\\"system\\":\\"VSP\\",\\"status\\":\\"500\\",\\"code\\":10000,\\"' \
                           'message\\":\\"Could not fetch appointments from Vista Scheduling Provider\\",\\"' \
                           'detail\\":\\"icn=d12672eba61b7e9bc50bb6085a0697133a5fbadf195e6cade452ddaad7921c1d, ' \
                           'startDate=2022-04-01T19:25Z, endDate=2023-03-01T19:45Z\\"}]"}'

            allow(Rails.logger).to receive(:info)

            subject.get_appointments(start_date3, end_date3)

            expect(Rails.logger).to have_received(:info).with(expected_msg)
          end
        end
      end

      context 'when requesting a list of appointments given a date range and single status' do
        it 'returns a 200 status with list of appointments' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_single_status_200',
                           allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
            response = subject.get_appointments(start_date2, end_date2, 'proposed')
            expect(response[:data].size).to eq(4)
            expect(response[:data][0][:status]).to eq('proposed')
          end
        end
      end

      context 'when there are CnP and covid appointments in the list' do
        it 'changes the cancellable status to false for CnP and covid appointments only' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_cnp_covid',
                           allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
            response = subject.get_appointments(start_date2, end_date2, 'proposed')
            # telehealth appointments, cancellable changed to false
            expect(response[:data][0][:cancellable]).to eq(false)
            # non CC, telehealth, CnP, covid appointment, cancellable left as is
            expect(response[:data][1][:cancellable]).to eq(true)
            expect(response[:data][2][:cancellable]).to eq(true)
            expect(response[:data][3][:cancellable]).to eq(true)
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

      context 'when requesting a list of appointments containing a booked cc appointment' do
        it 'sets cancellable to false' do
          Flipper.disable(:appointments_consolidation)
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility!).and_return(mock_facility2)
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_cc_booked',
                           allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
            response = subject.get_appointments(start_date2, end_date2)
            expect(response[:data][0][:kind]).to eq('cc')
            expect(response[:data][0][:status]).to eq('booked')
            expect(response[:data][0][:cancellable]).to eq(false)
            expect(response[:data][1][:kind]).to eq('cc')
            expect(response[:data][1][:status]).to eq('booked')
            expect(response[:data][1][:cancellable]).to eq(false)
          end
        end
      end

      context 'when requesting a list of appointments containing proposed or cancelled cc appointments' do
        it 'fetches provider info for a proposed cc appointment' do
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility!).and_return(mock_facility2)
          allow_any_instance_of(VAOS::V2::AppointmentProviderName).to receive(
            :form_names_from_appointment_practitioners_list
          ).and_return(provider_name)
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_cc_proposed',
                           allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
            response = subject.get_appointments(start_date2, end_date2)
            expect(response[:data][0][:preferred_provider_name]).not_to be_nil
          end
        end

        it 'fetches provider info for a cancelled cc appointment' do
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility!).and_return(mock_facility2)
          allow_any_instance_of(VAOS::V2::AppointmentProviderName).to receive(
            :form_names_from_appointment_practitioners_list
          ).and_return(provider_name)
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_cc_cancelled',
                           allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
            response = subject.get_appointments(start_date2, end_date2)
            expect(response[:data][0][:preferred_provider_name]).not_to be_nil
          end
        end
      end

      context '400' do
        it 'raises a 400 error' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_400',
                           match_requests_on: %i[method path query]) do
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

      it 'validates schema' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                         match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
          subject.get_appointments(start_date2, end_date2)
          SchemaContract::ValidationJob.drain
          expect(SchemaContract::Validation.last.status).to eq('success')
        end
      end
    end
  end

  describe '#get_appointment' do
    context 'using VAOS' do
      before do
        Flipper.disable(:va_online_scheduling_use_vpg)
      end

      context 'with an appointment' do
        context 'with Jacqueline Morgan' do
          it 'returns a proposed appointment' do
            allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility!).and_return(mock_facility)
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

      context 'when requesting a proposed CC appointment' do
        let(:user) { build(:user, :vaos) }

        it 'does not set the cancellable attribute to false' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_cc',
                           match_requests_on: %i[method path query]) do
            response = subject.get_appointment('159472')
            expect(response[:cancellable]).not_to eq(false)
          end
        end
      end

      context 'when requesting a Telehealth appointment' do
        let(:user) { build(:user, :vaos) }

        it 'sets the cancellable attribute to false' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_telehealth',
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

      describe '#get_recent_sorted_clinic_appointments' do
        subject { instance_of_class.get_recent_sorted_clinic_appointments }

        let(:instance_of_class) { described_class.new(user) }
        let(:mock_appointment_one) { double('Appointment', kind: 'clinic', start: '2022-12-02') }
        let(:mock_appointment_two) { double('Appointment', kind: 'telehealth', start: '2022-12-01T21:38:01.476Z') }
        let(:mock_appointment_three) { double('Appointment', kind: 'clinic', start: '2022-12-09T21:38:01.476Z') }

        context 'when appointments are available' do
          before do
            allow(instance_of_class).to receive(:get_appointments).and_return({ data: [mock_appointment_one,
                                                                                       mock_appointment_two,
                                                                                       mock_appointment_three] })
          end

          it 'returns the recent sorted clinic appointments' do
            expect(subject).to eq([mock_appointment_two, mock_appointment_one, mock_appointment_three])
          end
        end

        context 'when no appointments are available' do
          before do
            allow(instance_of_class).to receive(:get_appointments).and_return({ data: [] })
          end

          it 'returns nil' do
            expect(subject.first).to be_nil
          end
        end
      end

      describe '#sort_recent_appointments' do
        subject { instance_of_class }

        let(:instance_of_class) { described_class.new(user) }
        let(:mock_appointment_one) { double('Appointment', id: '123', kind: 'clinic', start: '2022-12-02') }
        let(:mock_appointment_two) do
          double('Appointment', id: '124', kind: 'telehealth', start: '2022-12-01T21:38:01.476Z')
        end
        let(:mock_appointment_three) do
          double('Appointment', id: '125', kind: 'clinic', start: '2022-12-09T21:38:01.476Z')
        end
        let(:mock_appointment_four_no_start) { double('Appointment', id: '126', kind: 'clinic', start: nil) }
        let(:appointments_input_no_start) do
          [mock_appointment_one, mock_appointment_two, mock_appointment_three, mock_appointment_four_no_start]
        end
        let(:appointments_input) { [mock_appointment_one, mock_appointment_two, mock_appointment_three] }
        let(:filtered_sorted_appointments) { [mock_appointment_two, mock_appointment_one, mock_appointment_three] }

        context 'when appointments are available' do
          it 'sorts based on start time' do
            expect(subject.send(:sort_recent_appointments, appointments_input)).to eq(filtered_sorted_appointments)
            expect(Rails.logger).not_to receive(:info)
          end
        end

        context 'when appointments are available and at least one is missing a start time' do
          it 'filters before sorting and logs removed appointments' do
            allow(Rails.logger).to receive(:info)
            expect(subject.send(:sort_recent_appointments,
                                appointments_input_no_start)).to eq(filtered_sorted_appointments)
            expect(Rails.logger).to have_received(:info)
              .with('VAOS appointment sorting filtered out id 126 due to missing start time.')
          end
        end
      end
    end
  end

  describe '#cancel_appointment' do
    context 'when the upstream server attempts to cancel an appointment' do
      context 'with Jaqueline Morgan' do
        context 'using vaos-service' do
          before do
            Flipper.disable(:va_online_scheduling_enable_OH_cancellations)
          end

          it 'returns a cancelled status and the cancelled appointment information' do
            VCR.use_cassette('vaos/v2/appointments/cancel_appointments_200',
                             match_requests_on: %i[method path query]) do
              VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                               match_requests_on: %i[method path query]) do
                VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200',
                                 match_requests_on: %i[method path query]) do
                  response = subject.update_appointment('70060', 'cancelled')
                  expect(response.status).to eq('cancelled')
                end
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
      end
    end

    context 'when there is a server error in updating an appointment' do
      before do
        Flipper.disable(:va_online_scheduling_enable_OH_cancellations)
      end

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
end
