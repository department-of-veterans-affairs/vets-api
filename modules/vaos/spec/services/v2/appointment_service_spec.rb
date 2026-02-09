# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'

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

  let(:appt_med) do
    { kind: 'clinic', service_category: [{ coding:
                                             [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' }] }] }
  end
  let(:appt_non) do
    { kind: 'clinic', service_category: [
                        { coding:
                                                               [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'SERVICE CONNECTED' }] }
                      ],
      service_type: 'SERVICE CONNECTED', service_types: [{ coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'SERVICE CONNECTED' }] }] }
  end
  let(:appt_cnp) do
    { kind: 'clinic', service_category: [{ coding:
                                             [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'COMPENSATION & PENSION' }] }] }
  end
  let(:appt_cc) do
    { kind: 'cc', service_category: [{ coding:
                                         [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' }] }] }
  end
  let(:appt_telehealth) do
    { kind: 'telehealth', service_category: [{ coding:
                                                 [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' }] }] }
  end
  let(:appt_no_service_cat) { { kind: 'clinic' } }

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
    allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_vaos_alternate_route).and_return(false)
  end

  describe '#post_appointment' do
    let(:va_proposed_clinic_request_body) do
      build(:appointment_form_v2, :va_proposed_clinic, user:).attributes
    end

    let(:va_proposed_phone_request_body) do
      build(:appointment_form_v2, :va_proposed_phone, user:).attributes
    end

    let(:va_booked_request_body) do
      build(:appointment_form_v2, :va_booked, user:).attributes
    end

    let(:community_cares_request_body) do
      build(:appointment_form_v2, :community_cares, user:).attributes
    end

    context 'using VAOS' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
      end

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
                expect(response[:pending]).to be(false)
                expect(response[:past]).to be(true)
                expect(response[:future]).to be(false)
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

    context 'using VPG' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(true)
      end

      context 'when va appointment create request is valid' do
        # appointment created using the Jacqueline Morgan user

        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(true)
        end

        it 'returns the created appointment - va - booked' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_JACQUELINE_M_vpg',
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
                expect(response[:pending]).to be(false)
                expect(response[:past]).to be(true)
                expect(response[:future]).to be(false)
              end
            end
          end
        end

        it 'returns the created appointment and logs data' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_and_logs_data_vpg',
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
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_proposed_clinic_200_vpg',
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
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(true)
        end

        it 'returns the created appointment - cc - proposed' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_cc_200_2222022_vpg',
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
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(true)
        end

        it 'raises a backend exception' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_400_vpg',
                           match_requests_on: %i[method path query]) do
            expect { subject.post_appointment(community_cares_request_body) }.to raise_error(
              Common::Exceptions::BackendServiceException
            )
          end
        end
      end

      context 'when the patientIcn is missing on a direct scheduling submission' do
        it 'raises a backend exception and logs error details' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_400_vpg',
                           match_requests_on: %i[method path query]) do
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
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(true)
        end

        it 'raises a backend exception' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_500_vpg',
                           match_requests_on: %i[method path query]) do
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
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
        allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(true)
        allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, instance_of(User)).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:appointments_consolidation, instance_of(User)).and_return(true)
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

        it 'returns partial error message' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200_and_log_data',
                           match_requests_on: %i[method path query]) do
            response = subject.get_appointments(start_date3, end_date3)
            partial_error_message = response[:meta][:partialErrorMessage]
            expect(partial_error_message[:request][:title]).to eq('We can’t show some of your requests right now.')
            expect(partial_error_message[:request][:body]).to eq('We’re working to fix this problem. To reschedule ' \
                                                                 'a request that’s not in this list, contact the ' \
                                                                 'VA facility where it was requested.')
            expect(partial_error_message[:booked][:title]).to eq('We can’t show some of your appointments right now.')
            expect(partial_error_message[:booked][:body]).to eq('We’re working to fix this problem. To manage an ' \
                                                                'appointment that’s not in this list, contact the ' \
                                                                'VA facility where it was scheduled.')
            expect(partial_error_message[:linkText]).to eq('Find your VA health facility')
            expect(partial_error_message[:linkUrl]).to eq('/find-locations')
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

      context 'when an appointment is in the past' do
        let(:appointment) { { status: 'booked', start: '2022-09-01T10:00:00-07:00' } }

        it 'changes cancellable status to false' do
          expect(subject.send(:cannot_be_cancelled?, appointment)).to be false
          appointment[:start] = '2021-09-01T10:00:00-07:00'
          expect(subject.send(:cannot_be_cancelled?, appointment)).to be true
        end
      end

      context 'when there are CnP and covid appointments in the list' do
        it 'changes the cancellable status to false for CnP and covid appointments only' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_cnp_covid',
                           allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
            response = subject.get_appointments(start_date2, end_date2, 'proposed')
            # telehealth appointments, cancellable changed to false
            expect(response[:data][0][:cancellable]).to be(false)
            # non CC, telehealth, CnP, covid appointment, cancellable left as is
            expect(response[:data][1][:cancellable]).to be(true)
            expect(response[:data][2][:cancellable]).to be(true)
            expect(response[:data][3][:cancellable]).to be(true)
            # CnP appointments, cancellable changed to false
            expect(response[:data][4][:cancellable]).to be(false)
            # covid appointments, cancellable changed to false
            expect(response[:data][5][:cancellable]).to be(false)
            expect(response[:data][6][:cancellable]).to be(false)
            expect(response[:data][7][:cancellable]).to be(false)
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
        it 'removes the service type(s) from only the non-med non-cnp appointment and covid appointments' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_non_med',
                           allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
            response = subject.get_appointments(start_date2, end_date2)
            expect(response[:data][0][:service_type]).to be_nil
            expect(response[:data][0][:service_types]).to be_nil
            expect(response[:data][1][:service_type]).to be_nil
            expect(response[:data][1][:service_types]).to be_nil
            expect(response[:data][2][:service_type]).not_to be_nil
            expect(response[:data][2][:service_types]).not_to be_nil
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
          allow(Flipper).to receive(:enabled?).with(:appointments_consolidation, instance_of(User)).and_return(false)
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility!).and_return(mock_facility2)
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_cc_booked',
                           allow_playback_repeats: true, match_requests_on: %i[method path query], tag: :force_utf8) do
            response = subject.get_appointments(start_date2, end_date2)
            expect(response[:data][0][:kind]).to eq('cc')
            expect(response[:data][0][:status]).to eq('booked')
            expect(response[:data][0][:cancellable]).to be(false)
            expect(response[:data][1][:kind]).to eq('cc')
            expect(response[:data][1][:status]).to eq('booked')
            expect(response[:data][1][:cancellable]).to be(false)
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

      context 'includes travel claims' do
        let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, user).and_return(true)
          allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(true)
          allow(Flipper).to receive(:enabled?).with(:appointments_consolidation, user).and_return(true)
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility).and_return(mock_facility)
          allow(TravelPay::AuthManager)
            .to receive(:new)
            .and_return(double('AuthManager', authorize: tokens))
          allow(Settings.travel_pay).to receive_messages(client_number: '12345', mobile_client_number: '56789')
        end

        it 'returns a list of appointments with travel claim information attached' do
          # Verify that the TravelPay::AuthManager is called with the correct client number
          expect(TravelPay::AuthManager).to receive(:new).with('12345', user)

          VCR.use_cassette('travel_pay/200_search_claims_by_appt_date_range', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                             allow_playback_repeats: true, match_requests_on: %i[method path], tag: :force_utf8) do
              response = subject.get_appointments(start_date2, end_date2, nil, {},
                                                  { travel_pay_claims: true })
              # The first appt with a start date
              appt_with_claim = response[:data][0]
              expect(appt_with_claim[:travelPayClaim]).not_to be_empty
              expect(appt_with_claim[:travelPayClaim]['claim']).not_to be_nil
              expect(appt_with_claim[:travelPayClaim]['metadata']['status']).to eq(200)
            end
          end
        end
      end

      context 'with parallel travel claims fetch enabled' do
        let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_parallel_travel_claims,
                                                    user).and_return(true)
          allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(true)
          allow(Flipper).to receive(:enabled?).with(:appointments_consolidation, user).and_return(true)
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility).and_return(mock_facility)
          allow(TravelPay::AuthManager)
            .to receive(:new)
            .and_return(double('AuthManager', authorize: tokens))
          allow(Settings.travel_pay).to receive_messages(client_number: '12345', mobile_client_number: '56789')
        end

        it 'fetches appointments and claims in parallel and returns merged data' do
          expect(TravelPay::AuthManager).to receive(:new).with('12345', user)

          VCR.use_cassette('travel_pay/200_search_claims_by_appt_date_range', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                             allow_playback_repeats: true, match_requests_on: %i[method path], tag: :force_utf8) do
              response = subject.get_appointments(start_date2, end_date2, nil, {},
                                                  { travel_pay_claims: true })

              # Verify the response structure
              appt_with_claim = response[:data][0]
              expect(appt_with_claim[:travelPayClaim]).not_to be_empty
              expect(appt_with_claim[:travelPayClaim]['claim']).not_to be_nil
              expect(appt_with_claim[:travelPayClaim]['metadata']['status']).to eq(200)
            end
          end
        end

        it 'handles travel claims service errors gracefully without failing the appointment request' do
          allow_any_instance_of(TravelPay::ClaimAssociationService)
            .to receive(:fetch_claims_by_date)
            .and_raise(StandardError.new('Travel claims service error'))

          expect(Rails.logger).to receive(:warn).with(/Travel claims fetch failed/)

          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                           allow_playback_repeats: true, match_requests_on: %i[method path], tag: :force_utf8) do
            response = subject.get_appointments(start_date2, end_date2, nil, {},
                                                { travel_pay_claims: true })

            # Appointments should still be returned
            expect(response[:data].size).to eq(16)
            # All appointments should have error metadata
            response[:data].each do |appt|
              expect(appt['travelPayClaim']).not_to be_nil
              expect(appt['travelPayClaim']['metadata']['success']).to be(false)
            end
          end
        end

        it 'handles appointment fetch errors and re-raises them' do
          allow_any_instance_of(VAOS::V2::AppointmentsService)
            .to receive(:send_appointments_request)
            .and_raise(Common::Exceptions::BackendServiceException.new('VAOS502'))

          expect do
            subject.get_appointments(start_date2, end_date2, nil, {}, { travel_pay_claims: true })
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end

        it 'logs errors when travel claims fetch fails but continues with appointments' do
          error_msg = 'Claims API timeout'
          allow_any_instance_of(TravelPay::ClaimAssociationService)
            .to receive(:fetch_claims_by_date)
            .and_raise(StandardError.new(error_msg))

          expect(Rails.logger).to receive(:error).with(/Error fetching travel claims in parallel/)
          expect(Rails.logger).to receive(:warn).with(/Travel claims fetch failed/)

          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                           allow_playback_repeats: true, match_requests_on: %i[method path], tag: :force_utf8) do
            response = subject.get_appointments(start_date2, end_date2, nil, {},
                                                { travel_pay_claims: true })
            expect(response[:data].size).to be_positive
          end
        end

        it 'works correctly when feature flag is disabled and uses sequential fetching' do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_parallel_travel_claims,
                                                    user).and_return(false)

          expect(TravelPay::AuthManager).to receive(:new).with('12345', user)

          VCR.use_cassette('travel_pay/200_search_claims_by_appt_date_range', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                             allow_playback_repeats: true, match_requests_on: %i[method path], tag: :force_utf8) do
              response = subject.get_appointments(start_date2, end_date2, nil, {},
                                                  { travel_pay_claims: true })

              # Should still work with sequential fetching
              appt_with_claim = response[:data][0]
              expect(appt_with_claim[:travelPayClaim]).not_to be_empty
              expect(appt_with_claim[:travelPayClaim]['claim']).not_to be_nil
              expect(appt_with_claim[:travelPayClaim]['metadata']['status']).to eq(200)
            end
          end
        end
      end
    end

    context 'when a MAP token error occurs' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(false)
      end

      it 'logs missing ICN error' do
        expected_error = MAP::SecurityToken::Errors::MissingICNError.new 'Missing ICN message'
        # Set up SessionService to raise the expected error. Although the error should be raised by
        # the MAP::SecurityToken::Service, it is easier to mock the behavior in this way for testing.
        # This is functionally equivalent since SessionService calls the MAP::SecurityToken::Service
        # in the :headers method.
        allow_any_instance_of(VAOS::SessionService).to receive(:headers).and_raise(expected_error)
        allow(Rails.logger).to receive(:warn).at_least(:once)
        result = subject.get_appointments(start_date, end_date)
        expect(Rails.logger).to have_received(:warn).with('VAOS::V2::AppointmentService#get_appointments missing ICN')
        expect(result[:data]).to eq({})
        expect(result[:meta][:failures]).to eq('Missing ICN message')
      end

      it 'logs application mismatch error' do
        expected_error = MAP::SecurityToken::Errors::ApplicationMismatchError.new 'Application Mismatch message'
        # Set up SessionService to raise the expected error. Although the error should be raised by
        # the MAP::SecurityToken::Service, it is easier to mock the behavior in this way for testing.
        # This is functionally equivalent since SessionService calls the MAP::SecurityToken::Service
        # in the :headers method.
        allow_any_instance_of(VAOS::SessionService).to receive(:headers).and_raise(expected_error)
        allow(Rails.logger).to receive(:warn).at_least(:once)
        result = subject.get_appointments(start_date, end_date)
        expect(Rails.logger).to have_received(:warn).with(
          'VAOS::V2::AppointmentService#get_appointments application mismatch',
          {
            icn: 'd12672eba61b7e9bc50bb6085a0697133a5fbadf195e6cade452ddaad7921c1d',
            context: 'Application Mismatch message'
          }
        )
        expect(result[:data]).to eq({})
        expect(result[:meta][:failures]).to eq('Application Mismatch message')
      end

      it 'logs gateway timeout error' do
        expected_error = Common::Exceptions::GatewayTimeout.new
        # Set up SessionService to raise the expected error. Although the error should be raised by
        # the MAP::SecurityToken::Service, it is easier to mock the behavior in this way for testing.
        # This is functionally equivalent since SessionService calls the MAP::SecurityToken::Service
        # in the :headers method.
        allow_any_instance_of(VAOS::SessionService).to receive(:headers).and_raise(expected_error)
        allow(Rails.logger).to receive(:warn).at_least(:once)
        result = subject.get_appointments(start_date, end_date)
        expect(Rails.logger).to have_received(:warn).with(
          'VAOS::V2::AppointmentService#get_appointments token failed, gateway timeout',
          {
            icn: 'd12672eba61b7e9bc50bb6085a0697133a5fbadf195e6cade452ddaad7921c1d'
          }
        )
        expect(result[:data]).to eq({})
        expect(result[:meta][:failures]).to eq('Gateway timeout')
      end

      it 'logs parsing error' do
        expected_error = Common::Client::Errors::ParsingError.new 'Parsing Error message'
        # Set up SessionService to raise the expected error. Although the error should be raised by
        # the MAP::SecurityToken::Service, it is easier to mock the behavior in this way for testing.
        # This is functionally equivalent since SessionService calls the MAP::SecurityToken::Service
        # in the :headers method.
        allow_any_instance_of(VAOS::SessionService).to receive(:headers).and_raise(expected_error)
        allow(Rails.logger).to receive(:warn).at_least(:once)
        result = subject.get_appointments(start_date, end_date)
        expect(Rails.logger).to have_received(:warn).with(
          'VAOS::V2::AppointmentService#get_appointments token failed, parsing error',
          {
            icn: 'd12672eba61b7e9bc50bb6085a0697133a5fbadf195e6cade452ddaad7921c1d',
            context: 'Parsing Error message'
          }
        )
        expect(result[:data]).to eq({})
        expect(result[:meta][:failures]).to eq('Parsing Error message')
      end

      it 'logs client error' do
        expected_error = Common::Client::Errors::ClientError.new 'Parsing Error message', 400, 'additional details'
        # Set up SessionService to raise the expected error. Although the error should be raised by
        # the MAP::SecurityToken::Service, it is easier to mock the behavior in this way for testing.
        # This is functionally equivalent since SessionService calls the MAP::SecurityToken::Service
        # in the :headers method.
        allow_any_instance_of(VAOS::SessionService).to receive(:headers).and_raise(expected_error)
        allow(Rails.logger).to receive(:warn).at_least(:once)
        result = subject.get_appointments(start_date, end_date)
        expect(Rails.logger).to have_received(:warn).with(
          'VAOS::V2::AppointmentService#get_appointments token failed, status: 400',
          {
            status: 400,
            icn: 'd12672eba61b7e9bc50bb6085a0697133a5fbadf195e6cade452ddaad7921c1d',
            context: 'additional details'
          }
        )
        expect(result[:data]).to eq({})
        expect(result[:meta][:failures])
          .to eq({
                   message: 'VAOS::V2::AppointmentService#get_appointments token failed, status: 400',
                   status: 400,
                   icn: 'd12672eba61b7e9bc50bb6085a0697133a5fbadf195e6cade452ddaad7921c1d',
                   context: 'additional details'
                 })
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

  describe '#get_sorted_recent_appointments' do
    subject { instance_of_class.get_sorted_recent_appointments }

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
        expect(subject).to eq([mock_appointment_three, mock_appointment_one, mock_appointment_two])
        expect(instance_of_class).to have_received(:get_appointments).once
      end
    end

    context 'when no appointments are available' do
      before do
        allow(instance_of_class).to receive(:get_appointments).and_return({ data: [] })
      end

      it 'returns nil' do
        expect(subject.first).to be_nil
        expect(instance_of_class).to have_received(:get_appointments).once
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
    let(:mock_appointment_three) { double('Appointment', id: '125', kind: 'clinic', start: '2022-12-09T21:38:01.476Z') }
    let(:mock_appointment_four_no_start) { double('Appointment', id: '126', kind: 'clinic', start: nil) }
    let(:appointments_input_no_start) do
      [mock_appointment_one, mock_appointment_two, mock_appointment_three, mock_appointment_four_no_start]
    end
    let(:appointments_input) { [mock_appointment_one, mock_appointment_two, mock_appointment_three] }
    let(:filtered_sorted_appointments) { [mock_appointment_three, mock_appointment_one, mock_appointment_two] }

    context 'when appointments are available' do
      it 'sorts based on start time' do
        expect(subject.send(:sort_recent_appointments, appointments_input)).to eq(filtered_sorted_appointments)
        expect(Rails.logger).not_to receive(:info)
      end
    end

    context 'when appointments are available and at least one is missing a start time' do
      it 'filters before sorting and logs removed appointments' do
        allow(Rails.logger).to receive(:info)
        expect(subject.send(:sort_recent_appointments, appointments_input_no_start)).to eq(filtered_sorted_appointments)
        expect(Rails.logger).to have_received(:info)
          .with('VAOS appointment sorting filtered out id 126 due to missing start time.')
      end
    end
  end

  describe '#get_appointment' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, user).and_return(true)
    end

    context 'using VAOS' do
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
              expect(response[:show_schedule_link]).to be_nil
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
            expect(resp[:show_schedule_link]).to be_nil
          end
        end

        it 'returns a booked cerner appointment without clinic fields' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_booked_cerner',
                           match_requests_on: %i[method path query]) do
            resp = subject.get_appointment('180402')
            expect(resp[:id]).to eq('180402')
            expect(resp.respond_to?(:service_name)).to be false
            expect(resp.respond_to?(:physical_location)).to be false
          end
        end
      end

      context 'when requesting a CnP appointment' do
        let(:user) { build(:user, :vaos) }

        it 'sets the cancellable attribute to false' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_CnP',
                           match_requests_on: %i[method path query]) do
            response = subject.get_appointment('159472')
            expect(response[:cancellable]).to be(false)
            expect(response[:show_schedule_link]).to be_nil
          end
        end
      end

      context 'when requesting a proposed CC appointment' do
        let(:user) { build(:user, :vaos) }

        it 'does not set the cancellable attribute to false' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_cc',
                           match_requests_on: %i[method path query]) do
            response = subject.get_appointment('159472')
            expect(response[:cancellable]).not_to be(false)
            expect(response[:show_schedule_link]).to be_nil
          end
        end
      end

      context 'when requesting a Telehealth appointment' do
        let(:user) { build(:user, :vaos) }

        it 'sets the cancellable attribute to false' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_telehealth',
                           match_requests_on: %i[method path query]) do
            response = subject.get_appointment('159472')
            expect(response[:cancellable]).to be(false)
            expect(response[:show_schedule_link]).to be_nil
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
            expect(response[:show_schedule_link]).to be_nil
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

      context 'when travel reimbursement claims are included' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, user).and_return(true)
          allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(true)
          allow(Flipper).to receive(:enabled?).with(:appointments_consolidation, user).and_return(true)
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility).and_return(mock_facility)
        end

        it 'returns an appointment with a travel claim attached if claim exists' do
          VCR.use_cassette('travel_pay/200_search_claims_by_appt_date_range', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                             allow_playback_repeats: true, match_requests_on: %i[method path], tag: :force_utf8) do
              response = subject.get_appointments(start_date2, end_date2, nil, {},
                                                  { travel_pay_claims: true })
              # The first appt with a start date
              appt_with_claim = response[:data][0]
              expect(appt_with_claim[:travelPayClaim]).not_to be_empty
              expect(appt_with_claim[:travelPayClaim]['claim']).not_to be_nil
              expect(appt_with_claim[:travelPayClaim]['metadata']['status']).to eq(200)
            end
          end
        end

        it 'returns an appointment without a travel claim attached if claim does not exist' do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, user).and_return(true)
          allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(true)
          allow(Flipper).to receive(:enabled?).with(:appointments_consolidation, user).and_return(true)
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility!).and_return(mock_facility)

          VCR.use_cassette('travel_pay/200_search_claims_by_appt_date_instance_no_claims',
                           match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointment_200_with_facility_200_with_avs',
                             allow_playback_repeats: true, match_requests_on: %i[method path], tag: :force_utf8) do
              response = subject.get_appointment('70060', { travel_pay_claims: true })

              expect(response[:travelPayClaim]).not_to be_empty
              expect(response[:travelPayClaim]['claim']).to be_nil
              expect(response[:travelPayClaim]['metadata']['status']).to eq(200)
            end
          end
        end
      end
    end

    context 'using VPG' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(true)
        allow(Flipper).to receive(:enabled?).with(:appointments_consolidation, user).and_return(true)
      end

      context 'with an appointment' do
        context 'with Jacqueline Morgan' do
          it 'returns a proposed appointment' do
            allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility!).and_return(mock_facility)
            VCR.use_cassette('vaos/v2/appointments/get_appointment_200_with_facility_200_vpg',
                             match_requests_on: %i[method path query]) do
              response = subject.get_appointment('70060')
              expect(response[:id]).to eq('70060')
              expect(response[:kind]).to eq('clinic')
              expect(response[:status]).to eq('proposed')
              expect(response[:requested_periods][0][:local_start_time]).to eq('Sun, 19 Dec 2021 19:00:00 -0500')
              expect(response[:show_schedule_link]).to be_nil
            end
          end
        end
      end

      context 'when requesting a booked cerner appointment' do
        let(:user) { build(:user, :vaos) }

        it 'returns a booked cerner appointment with the requested periods set to nil' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_booked_cerner_vpg',
                           match_requests_on: %i[method path query]) do
            resp = subject.get_appointment('180402')
            expect(resp[:id]).to eq('180402')
            expect(resp[:requested_periods]).to be_nil
            expect(resp[:show_schedule_link]).to be_nil
          end
        end

        it 'returns a booked cerner appointment without clinic fields' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_booked_cerner_vpg',
                           match_requests_on: %i[method path query]) do
            resp = subject.get_appointment('180402')
            expect(resp[:id]).to eq('180402')
            expect(resp.respond_to?(:service_name)).to be false
            expect(resp.respond_to?(:physical_location)).to be false
          end
        end
      end

      context 'when requesting a CnP appointment' do
        let(:user) { build(:user, :vaos) }

        it 'sets the cancellable attribute to false' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_CnP_vpg',
                           match_requests_on: %i[method path query]) do
            response = subject.get_appointment('159472')
            expect(response[:cancellable]).to be(false)
            expect(response[:show_schedule_link]).to be_nil
          end
        end
      end

      context 'when requesting a Telehealth appointment' do
        let(:user) { build(:user, :vaos) }

        it 'sets the cancellable attribute to false' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_telehealth_vpg',
                           match_requests_on: %i[method path query]) do
            response = subject.get_appointment('159472')
            expect(response[:cancellable]).to be(false)
            expect(response[:show_schedule_link]).to be_nil
          end
        end
      end

      context 'when requesting a proposed CC appointment' do
        let(:user) { build(:user, :vaos) }

        it 'does not set the cancellable attribute as false' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_cc_vpg',
                           match_requests_on: %i[method path query]) do
            response = subject.get_appointment('159472')
            expect(response[:cancellable]).not_to be(false)
            expect(response[:show_schedule_link]).to be_nil
          end
        end
      end

      context 'when requesting a non-Med non-CnP appointment' do
        let(:user) { build(:user, :vaos) }

        it 'removes the appointments service type and service types attributes' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_non_med_vpg',
                           match_requests_on: %i[method path query]) do
            response = subject.get_appointment('159472')
            expect(response[:service_type]).to be_nil
            expect(response[:service_types]).to be_nil
            expect(response[:show_schedule_link]).to be_nil
          end
        end
      end

      context 'when requesting a cancelled appointment' do
        let(:user) { build(:user, :jac) }

        it 'sets the cancellable attribute to false' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_cancelled_vpg',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                             match_requests_on: %i[method path query]) do
              response = subject.get_appointment('70060')
              expect(response[:cancellable]).to be(true)
              expect(response[:show_schedule_link]).to be(true)
            end
          end
        end
      end

      context 'when the upstream server returns a 500' do
        it 'raises a backend exception' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_500_vpg', match_requests_on: %i[method path query]) do
            expect { subject.get_appointment('00000') }.to raise_error(
              Common::Exceptions::BackendServiceException
            )
          end
        end
      end
    end
  end

  describe '#cancel_appointment' do
    context 'when the upstream server attempts to cancel an appointment' do
      context 'with Jaqueline Morgan' do
        context 'using VPG' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(true)
            allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, user).and_return(true)
            allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(true)
            allow(Flipper).to receive(:enabled?).with(:appointments_consolidation, user).and_return(true)
          end

          it 'returns a cancelled status and the cancelled appointment information' do
            VCR.use_cassette('vaos/v2/appointments/cancel_appointments_vpg_204',
                             match_requests_on: %i[method path query body_as_json]) do
              VCR.use_cassette('vaos/v2/appointments/get_appointment_200_cancelled_vpg',
                               match_requests_on: %i[method path query body_as_json]) do
                VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                                 match_requests_on: %i[method path query]) do
                  response = subject.update_appointment('70060', 'cancelled')
                  expect(response.status).to eq('cancelled')
                  expect(response[:show_schedule_link]).to be(true)
                  expect(response[:modality]).to be('vaInPerson')
                  expect(response[:past]).to be(true)
                  expect(response[:pending]).to be(true)
                  expect(response[:future]).to be(false)
                end
              end
            end
          end

          it 'returns a 400 when the appointment is not cancellable' do
            VCR.use_cassette('vaos/v2/appointments/cancel_appointment_vpg_400',
                             match_requests_on: %i[method path query]) do
              expect { subject.update_appointment('42081', 'cancelled') }
                .to raise_error do |error|
                  expect(error).to be_a(Common::Exceptions::BackendServiceException)
                  expect(error.status_code).to eq(400)
              end
            end
          end
        end

        context 'using vaos-service' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                      user).and_return(false)
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
                  expect(response[:show_schedule_link]).to be(true)
                  expect(response[:modality]).to be('vaInPerson')
                  expect(response[:past]).to be(true)
                  expect(response[:pending]).to be(true)
                  expect(response[:future]).to be(false)
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
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(false)
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

  describe '#get_facility_timezone' do
    let(:facility_location_id) { '983' }
    let(:facility_error_msg) { 'Error fetching facility details' }

    context 'with a facility location id' do
      it 'returns the facility timezone' do
        allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility!).and_return(mock_facility)
        timezone = subject.send(:get_facility_timezone, facility_location_id)
        expect(timezone).to eq('America/New_York')
      end
    end

    context 'with an internal server error from the facilities call' do
      it 'returns nil for the timezone' do
        allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility!)
          .and_raise(Common::Exceptions::BackendServiceException)
        timezone = subject.send(:get_facility_timezone, facility_location_id)
        expect(timezone).to be_nil
      end
    end
  end

  describe '#get_appointments merge' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(true)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:appointments_consolidation, instance_of(User)).and_return(true)
    end

    context 'when include eps is true' do
      it 'merges eps appointments with vaos appointments' do
        VCR.use_cassette('vaos/eps/get_vaos_appointments_200_with_merge',
                         match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
          VCR.use_cassette('vaos/eps/token/token_200',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_appointments/200',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              VCR.use_cassette('vaos/eps/get_provider_service/get_multiple_providers_200',
                               match_requests_on: %i[method path],
                               allow_playback_repeats: true, tag: :force_utf8) do
                result = subject.get_appointments(start_date, end_date, nil, {}, { eps: true })
                expect(result[:data].map { |appt| appt[:referral][:referral_number] }).to include('12345')
                expect(result[:data].map { |appt| appt[:id].to_s }).to include('101', '102', '186')
              end
            end
          end
        end
      end

      it 'merges eps appointments with vaos appointments and removes eps appointment with duplicate referralNumbers ' \
         'but not the vaos appointment' do
        VCR.use_cassette('vaos/eps/get_vaos_appointments_200_with_merge',
                         match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
          VCR.use_cassette('vaos/eps/token/token_200',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_appointments/200',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              VCR.use_cassette('vaos/eps/get_provider_service/get_multiple_providers_200',
                               match_requests_on: %i[method path],
                               allow_playback_repeats: true, tag: :force_utf8) do
                result = subject.get_appointments(start_date, end_date, nil, {}, { eps: true })
                expect(result[:data].map { |appt| appt[:id].to_s }).not_to include('thedupe')
              end
            end
          end
        end
      end

      it 'handles no matching referral number' do
        VCR.use_cassette('vaos/eps/get_vaos_appointments_200_with_merge',
                         match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
          VCR.use_cassette('vaos/eps/token/token_200',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_appointments/200',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              VCR.use_cassette('vaos/eps/get_provider_service/get_multiple_providers_200',
                               match_requests_on: %i[method path],
                               allow_playback_repeats: true, tag: :force_utf8) do
                result = subject.get_appointments(start_date, end_date, nil, {}, { eps: true })
                expect(result[:data].map do |appt|
                  appt[:referral][:referral_number]
                end).not_to include('nonexistent_referral')
              end
            end
          end
        end
      end

      it 'handles nil start date in eps appointments' do
        VCR.use_cassette('vaos/eps/get_vaos_appointments_200_with_merge',
                         match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
          VCR.use_cassette('vaos/eps/token/token_200',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_appointments/200',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              VCR.use_cassette('vaos/eps/get_provider_service/get_multiple_providers_200',
                               match_requests_on: %i[method path],
                               allow_playback_repeats: true, tag: :force_utf8) do
                result = subject.get_appointments(start_date, end_date, nil, {}, { eps: true })
                expect(result[:data].map { |appt| appt[:id].to_s }).not_to include('123')
              end
            end
          end
        end
      end

      it 'handles vaos appointments and empty eps_appointments' do
        VCR.use_cassette('vaos/eps/get_vaos_appointments_200_with_merge',
                         match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
          VCR.use_cassette('vaos/eps/token/token_200',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_appointments/200_empty',
                             match_requests_on: %i[method path query],
                             allow_playback_repeats: true, tag: :force_utf8) do
              result = subject.get_appointments(start_date, end_date, nil, {}, { eps: true })
              expect(result[:data].map do |appt|
                appt[:referral][:referral_number]
              end).to include('0987654321', '1234567890', '1122334455', '6677889900', '1234567890')
            end
          end
        end
      end

      it 'handles empty appointment data' do
        VCR.use_cassette('vaos/eps/get_appointments_empty_data',
                         match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
          VCR.use_cassette('vaos/eps/token/token_200',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_appointments/200_empty',
                             match_requests_on: %i[method path query],
                             allow_playback_repeats: true, tag: :force_utf8) do
              result = subject.get_appointments(start_date, end_date, nil, {}, { eps: true })
              expect(result[:data].map { |appt| appt[:referral][:referral_number] }).to be_empty
            end
          end
        end
      end

      it 'sets future and past flags on eps appointments based on start time' do
        VCR.use_cassette('vaos/eps/get_vaos_appointments_200_with_merge',
                         match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
          Timecop.freeze(Time.zone.parse('2024-12-02T12:01:00Z')) do
            VCR.use_cassette('vaos/eps/token/token_200',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              VCR.use_cassette('vaos/eps/get_appointments/200',
                               match_requests_on: %i[method path],
                               allow_playback_repeats: true, tag: :force_utf8) do
                VCR.use_cassette('vaos/eps/get_provider_service/get_multiple_providers_200',
                                 match_requests_on: %i[method path],
                                 allow_playback_repeats: true, tag: :force_utf8) do
                  result = subject.get_appointments(start_date, end_date, nil, {}, { eps: true })
                  data = result[:data]

                  eps_appt = data.find { |a| a.dig(:referral, :referral_number) == '12345' }

                  expect(eps_appt).not_to be_nil

                  # Check that the appointment has past/future flags set
                  expect(eps_appt[:past]).to be_in([true, false])
                  expect(eps_appt[:future]).to be_in([true, false])
                end
              end
            end
          end
        end
      end

      it 'merges provider data correctly' do
        VCR.use_cassette('vaos/eps/token/token_200',
                         match_requests_on: %i[method path],
                         allow_playback_repeats: true, tag: :force_utf8) do
          VCR.use_cassette('vaos/eps/get_vaos_appointments_200_with_merge',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_eps_appointments_200',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              VCR.use_cassette('vaos/eps/get_provider_service/get_multiple_providers_200',
                               match_requests_on: %i[method path],
                               allow_playback_repeats: true, tag: :force_utf8) do
                result = subject.get_appointments(start_date, end_date, nil, {}, { eps: true })
                provider_names = result[:data].map { |appt| appt[:provider_name] }
                expect(provider_names).to include(
                  'Dr. Moreen S. Rafa @ FHA South Melbourne Medical Complex'
                )
                expect(provider_names).to include(
                  'Dr. Bruce Roly @ FHA Urology of Orlando'
                )
              end
            end
          end
        end
      end

      it 'includes eps appointments with provider names when available' do
        VCR.use_cassette('vaos/eps/token/token_200',
                         match_requests_on: %i[method path],
                         allow_playback_repeats: true, tag: :force_utf8) do
          VCR.use_cassette('vaos/eps/get_vaos_appointments_200_with_merge',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_eps_appointments_200',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              VCR.use_cassette('vaos/eps/get_provider_service/get_multiple_providers_200',
                               match_requests_on: %i[method path],
                               allow_playback_repeats: true, tag: :force_utf8) do
                result = subject.get_appointments(start_date, end_date, nil, {}, { eps: true })
                # Find any EPS appointment that has provider data
                provider_appt = result[:data].find do |x|
                  x[:provider_service_id].present?
                end
                expect(provider_appt).not_to be_nil
                expect(provider_appt[:provider_name]).to be_present
              end
            end
          end
        end
      end

      it 'defaults provider_name to "unknown" for eps appointments without provider name' do
        # Mock EPS response with appointment missing provider name
        eps_appointment_data = {
          id: 'test-123',
          state: 'booked',
          patient_id: user.icn,
          provider_service_id: 'provider-123',
          appointment_details: {
            status: 'booked',
            start: '2023-11-01T10:00:00Z'
          },
          referral: {
            referral_number: 'REF-12345'
          }
          # NOTE: No provider field
        }

        eps_appointment = VAOS::V2::EpsAppointment.new(eps_appointment_data)
        expect(eps_appointment.provider_name).to eq('unknown')
      end
    end
  end

  describe '#get_active_appointments_for_referral' do
    before do
      Timecop.freeze(DateTime.parse('2021-09-02T14:00:00Z'))
      allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(true)
    end

    after do
      Timecop.return
    end

    context 'when both EPS and VAOS have appointments' do
      it 'returns appointments from both sources with normalized status and ordered most to least recent' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200_v2',
                         match_requests_on: %i[method query]) do
          VCR.use_cassette('vaos/eps/token/token_200',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_appointments/mixed_statuses_for_referral_test',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              result = subject.get_active_appointments_for_referral('ref-123')

              # EPS appointments should be ordered most to least recent
              # Expected order: appt2 (2024-11-21T18:00:00Z), appt1 (2024-11-20T17:00:00Z), appt4 (2024-11-19T18:00:00Z)
              # appt3 is filtered out because state is "draft"
              mapped_eps = result[:EPS][:data].map { |a| { id: a[:id], status: a[:status], start: a[:start] } }
              expect(mapped_eps).to eq([
                                         { id: 'appt2', status: 'cancelled', start: '2024-11-21T18:00:00Z' },
                                         { id: 'appt1', status: 'active', start: '2024-11-20T17:00:00Z' },
                                         { id: 'appt4', status: 'active', start: '2024-11-19T18:00:00Z' }
                                       ])

              # VAOS appointments should be ordered most to least recent
              # Expected order: 50060 (2024-11-22T18:00:00Z), 50061 (2024-11-21T10:00:00Z)
              mapped_vaos = result[:VAOS][:data].map { |a| { id: a[:id], status: a[:status], start: a[:start] } }
              expect(mapped_vaos).to eq([
                                          { id: '50060', status: 'cancelled', start: '2024-11-22T18:00:00Z' },
                                          { id: '50061', status: 'active', start: '2024-11-21T10:00:00Z' }
                                        ])
            end
          end
        end
      end
    end

    context 'when EPS has no appointments' do
      it 'returns empty EPS data and VAOS appointments' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200_v2',
                         match_requests_on: %i[method query]) do
          VCR.use_cassette('vaos/eps/token/token_200',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_appointments/200_empty',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              result = subject.get_active_appointments_for_referral('ref-150')

              expect(result[:EPS][:data]).to eq([])
              expect(result[:VAOS][:data]).to be_an(Array)
            end
          end
        end
      end
    end

    context 'when EPS fails to fetch appointments' do
      it 'logs the error and re-raises the exception' do
        allow_any_instance_of(Eps::AppointmentService).to receive(:get_appointments)
          .and_raise(Common::Exceptions::BackendServiceException.new('EPS_502', { source: 'EPS' }))

        expect(Rails.logger).to receive(:error)
          .with(/Failed to fetch EPS appointments for referral \*\*\*1234/)

        expect do
          subject.get_active_appointments_for_referral('test-referral-1234')
        end.to raise_error(Common::Exceptions::BackendServiceException)
      end
    end

    context 'when VAOS fails to fetch appointments' do
      it 'logs the error and re-raises the exception' do
        appointments_service = VAOS::V2::AppointmentsService.new(user)
        allow(VAOS::V2::AppointmentsService).to receive(:new).and_return(appointments_service)

        VCR.use_cassette('vaos/eps/token/token_200',
                         match_requests_on: %i[method path],
                         allow_playback_repeats: true, tag: :force_utf8) do
          VCR.use_cassette('vaos/eps/get_appointments/200_empty',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            allow(appointments_service).to receive(:get_all_appointments)
              .and_raise(Common::Exceptions::BackendServiceException.new('VAOS_502', { detail: 'VAOS error' }))

            expect(Rails.logger).to receive(:error)
              .with(/Failed to fetch VAOS appointments for referral \*\*\*5678/)

            expect do
              appointments_service.get_active_appointments_for_referral('test-referral-5678')
            end.to raise_error(StandardError)
          end
        end
      end
    end
  end

  describe '#referral_appointment_already_exists?' do
    before do
      Timecop.freeze(DateTime.parse('2021-09-02T14:00:00Z'))
      allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(true)
    end

    context 'when requests to check existing appointments are successful' do
      it 'returns hash with boolean indicating no existing appointments are tied to referral' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200',
                         match_requests_on: %i[method query]) do
          VCR.use_cassette('vaos/eps/token/token_200',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_appointments/200_empty',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              check = subject.referral_appointment_already_exists?('ref-150')
              expect(check).to be_a(Hash)
              expect(check[:exists]).to be(false)
              expect(check).not_to have_key(:failure)
            end
          end
        end
      end

      it 'returns hash with boolean indicating there is an existing CCRA appointment' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200',
                         match_requests_on: %i[method query]) do
          VCR.use_cassette('vaos/eps/token/token_200',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_appointments/200',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              check = subject.referral_appointment_already_exists?('ref-122')
              expect(check).to be_a(Hash)
              expect(check[:exists]).to be(true)
              expect(check).not_to have_key(:failure)
            end
          end
        end
      end

      it 'returns hash with boolean indicating there is an existing EPS appointment' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200',
                         match_requests_on: %i[method query]) do
          VCR.use_cassette('vaos/eps/token/token_200',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_appointments/200_with_referral_number_ref-123',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              check = subject.referral_appointment_already_exists?('ref124')
              expect(check).to be_a(Hash)
              expect(check[:exists]).to be(true)
              expect(check).not_to have_key(:failure)
            end
          end
        end
      end

      # replicates tests for get_appointments to ensure consistent logging
      context 'upstream api failures' do
        context 'when the call for vaos appointments returns a partial failure' do
          it 'logs the failures, anonymizes the ICNs sent to the log, and returns the failure messages' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_partial_errors_v2',
                             match_requests_on: %i[method path query]) do
              expected_msg = 'VAOS::V2::AppointmentService#get_all_appointments has response errors. : ' \
                             '{:failures=>"[{\\"system\\":\\"VSP\\",\\"status\\":\\"500\\",\\"code\\":10000,\\"' \
                             'message\\":\\"Could not fetch appointments from Vista Scheduling Provider\\",\\"' \
                             'detail\\":\\"icn=d12672eba61b7e9bc50bb6085a0697133a5fbadf195e6cade452ddaad7921c1d, ' \
                             'startDate=1921-09-02T00:00:00Z, endDate=2121-09-02T00:00:00Z\\"}]"}'

              allow(Rails.logger).to receive(:info)

              check = subject.referral_appointment_already_exists?('ref-150')
              expect(Rails.logger).to have_received(:info).with(expected_msg)
              expect(check).to be_a(Hash)
              expect(check).not_to have_key(:exists)
              expect(check[:error]).to be(true)
              expect(check).to have_key(:failures)
              expect(check[:failures].count).to eq(1)
              expect(check[:failures][0][:message]).to eq('Could not fetch appointments from Vista Scheduling Provider')
            end
          end
        end

        context 'when a MAP token error occurs' do
          it 'logs missing ICN error' do
            expected_error = MAP::SecurityToken::Errors::MissingICNError.new 'Missing ICN message'
            allow_any_instance_of(VAOS::SessionService).to receive(:headers).and_raise(expected_error)
            allow(Rails.logger).to receive(:warn).at_least(:once)
            check = subject.referral_appointment_already_exists?('ref-150')

            expected_message = 'VAOS::V2::AppointmentService#get_all_appointments missing ICN'
            expect(Rails.logger)
              .to have_received(:warn)
              .with(expected_message)
            expect(check[:failures]).to eq('Missing ICN message')
          end
        end
      end
    end

    describe 'EPS mock bypass behavior' do
      let(:referral_id) { 'ref124' }
      let(:eps_config) { instance_double(Eps::Configuration) }

      context 'when EPS mocks are enabled' do
        before do
          allow_any_instance_of(Eps::Configuration).to receive(:mock_enabled?).and_return(true)
        end

        it 'bypasses VAOS call and only checks EPS appointments' do
          VCR.use_cassette('vaos/eps/token/token_200',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/eps/get_appointments/200',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              result = subject.referral_appointment_already_exists?(referral_id)

              expect(result[:exists]).to be(true)
              expect(result).not_to have_key(:error)
              expect(result).not_to have_key(:failures)
            end
          end
        end
      end

      context 'when EPS mocks are disabled' do
        before do
          allow_any_instance_of(Eps::Configuration).to receive(:mock_enabled?).and_return(false)
        end

        it 'calls VAOS API to check appointments' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200',
                           match_requests_on: %i[method query]) do
            VCR.use_cassette('vaos/eps/token/token_200',
                             match_requests_on: %i[method path],
                             allow_playback_repeats: true, tag: :force_utf8) do
              VCR.use_cassette('vaos/eps/get_appointments/200',
                               match_requests_on: %i[method path],
                               allow_playback_repeats: true, tag: :force_utf8) do
                result = subject.referral_appointment_already_exists?(referral_id)

                expect(result[:exists]).to be(true)
              end
            end
          end
        end
      end
    end
  end

  describe '#convert_appointment_time' do
    let(:manila_appt) do
      {
        id: '12345',
        location_id: '358',
        start: '2024-12-20T00:00:00Z'
      }
    end

    let(:manila_appt_req) do
      {
        id: '12345',
        location_id: '358',
        requested_periods: [{ start: '2024-12-20T00:00:00Z', end: '2024-12-20T11:59:59.999Z' }]
      }
    end

    context 'when appt location id is 358' do
      it 'logs the appt location id, timezone info, utc/local times of appt' do
        allow_any_instance_of(VAOS::V2::AppointmentsService)
          .to receive(:get_facility_timezone_memoized)
          .and_return('Asia/Manila')
        allow(Rails.logger).to receive(:info)

        subject.send(:convert_appointment_time, manila_appt)
        expect(Rails.logger).to have_received(:info).with('Timezone info for Manila Philippines location_id 358',
                                                          {
                                                            location_id: '358',
                                                            facility_timezone: 'Asia/Manila',
                                                            appt_start_time_utc: '2024-12-20T00:00:00Z',
                                                            appt_start_time_local: subject.send(
                                                              :convert_utc_to_local_time,
                                                              manila_appt[:start],
                                                              'Asia/Manila'
                                                            )
                                                          }.to_json)
      end

      it 'logs the appt location id, timezone info, utc/local times of appt request' do
        allow_any_instance_of(VAOS::V2::AppointmentsService)
          .to receive(:get_facility_timezone_memoized)
          .and_return('Asia/Manila')
        allow(Rails.logger).to receive(:info)

        subject.send(:convert_appointment_time, manila_appt_req)
        expect(Rails.logger).to have_received(:info).with('Timezone info for Manila Philippines location_id 358',
                                                          {
                                                            location_id: '358',
                                                            facility_timezone: 'Asia/Manila',
                                                            appt_start_time_utc: '2024-12-20T00:00:00Z',
                                                            appt_start_time_local: subject.send(
                                                              :convert_utc_to_local_time, manila_appt_req.dig(
                                                                                            :requested_periods,
                                                                                            0,
                                                                                            :start
                                                                                          ), 'Asia/Manila'
                                                            )
                                                          }.to_json)
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
      expect(subject.send(:medical?, appt_med)).to be(true)
    end

    it 'returns false for non-medical appointments' do
      expect(subject.send(:medical?, appt_non)).to be(false)
    end
  end

  describe '#no_service_cat?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:no_service_cat?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true for appointments without a service category' do
      expect(subject.send(:no_service_cat?, appt_no_service_cat)).to be(true)
    end

    it 'returns false for appointments with a service category' do
      expect(subject.send(:no_service_cat?, appt_non)).to be(false)
    end
  end

  describe '#cnp?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:cnp?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true for compensation and pension appointments' do
      expect(subject.send(:cnp?, appt_cnp)).to be(true)
    end

    it 'returns false for non compensation and pension appointments' do
      expect(subject.send(:cnp?, appt_non)).to be(false)
    end
  end

  describe '#cc?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:cc?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true for community care appointments' do
      expect(subject.send(:cc?, appt_cc)).to be(true)
    end

    it 'returns false for non community care appointments' do
      expect(subject.send(:cc?, appt_non)).to be(false)
    end
  end

  describe '#telehealth?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:telehealth?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true for telehealth appointments' do
      expect(subject.send(:telehealth?, appt_telehealth)).to be(true)
    end

    it 'returns false for telehealth appointments' do
      expect(subject.send(:telehealth?, appt_non)).to be(false)
    end
  end

  describe '#remove_service_type' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:remove_service_type, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'Modifies the appointment with service type(s) removed from appointment' do
      expect { subject.send(:remove_service_type, appt_non) }.to change(appt_non, :keys)
        .from(%i[kind service_category service_type
                 service_types])
        .to(%i[kind service_category])
    end
  end

  describe '#booked?' do
    it 'returns true when the appointment status is booked' do
      appt = {
        status: 'booked'
      }

      expect(subject.send(:booked?, appt)).to be(true)
    end

    it 'returns false when the appointment status is not booked' do
      appt = {
        status: 'cancelled'
      }

      expect(subject.send(:booked?, appt)).to be(false)
    end

    it 'returns false when the appointment does not contain status' do
      appt = {}

      expect(subject.send(:booked?, appt)).to be(false)
    end

    it 'raises an ArgumentError when the appointment nil' do
      expect { subject.send(:booked?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end
  end

  describe '#extract_station_and_ien' do
    it 'returns nil if the appointment does not have any identifiers' do
      appointment = {}

      expect(subject.send(:extract_station_and_ien, appointment)).to be_nil
    end

    it 'returns nil if the identifier with the system VistADefinedTerms/409_84 is not found' do
      appointment = { identifier: [{ system: 'some_other_system', value: 'some_value' }] }

      expect(subject.send(:extract_station_and_ien, appointment)).to be_nil
    end

    it 'returns the station id and ien if the identifier with the system VistADefinedTerms/409_84 is found' do
      appointment = { identifier: [{ system: '/Terminology/VistADefinedTerms/409_84', value: '983:12345678' }] }
      expected_result = %w[983 12345678]

      expect(subject.send(:extract_station_and_ien, appointment)).to eq(expected_result)
    end

    it 'returns the station id and ien if the identifier with the system VistADefinedTerms/409_85 is found' do
      appointment = { identifier: [{ system: '/Terminology/VistADefinedTerms/409_85', value: '983:12345678' }] }
      expected_result = %w[983 12345678]

      expect(subject.send(:extract_station_and_ien, appointment)).to eq(expected_result)
    end
  end

  describe '#extract_cerner_identifier' do
    it 'returns nil if the appointment does not have any identifiers' do
      appointment = {}

      expect(subject.send(:extract_cerner_identifier, appointment)).to be_nil
    end

    it 'returns nil if the identifier with the cerner system is not found' do
      appointment = { identifier: [{ system: 'some_other_system', value: 'some_value' }] }

      expect(subject.send(:extract_cerner_identifier, appointment)).to be_nil
    end

    it 'returns the cerner appt id number if the identifier with the cerner system is found' do
      appointment = { identifier: [{ system: 'urn:va.gov:masv2:cerner:appointment', value: 'Appointment/1234567' }] }
      expected_result = '1234567'

      expect(subject.send(:extract_cerner_identifier, appointment)).to eq(expected_result)
    end
  end

  describe '#avs_applicable?' do
    before { travel_to(DateTime.parse('2023-09-26T10:00:00-07:00')) }
    after { travel_back }

    let(:past_appointment) { { status: 'booked', start: '2023-09-25T10:00:00-07:00' } }
    let(:fulfilled_appointment) { { status: 'fulfilled', start: '2023-09-25T10:00:00-07:00' } }
    let(:future_appointment) { { status: 'booked', start: '2023-09-27T11:00:00-07:00' } }
    let(:unbooked_appointment) { { status: 'pending', start: '2023-09-25T10:00:00-07:00' } }
    let(:avs_param_included) { true }
    let(:avs_param_excluded) { false }

    it 'returns true if the appointment is booked and is in the past and avs is included' do
      expect(subject.send(:avs_applicable?, past_appointment, avs_param_included)).to be true
    end

    it 'returns true if the appointment is fulfilled and is in the past and avs is included' do
      expect(subject.send(:avs_applicable?, fulfilled_appointment, avs_param_included)).to be true
    end

    it 'returns false if the appointment is not booked' do
      expect(subject.send(:avs_applicable?, unbooked_appointment, avs_param_included)).to be false
    end

    it 'returns false on a booked future appointment' do
      expect(subject.send(:avs_applicable?, future_appointment, avs_param_included)).to be false
    end

    it 'returns false if the avs param is not included' do
      expect(subject.send(:avs_applicable?, past_appointment, avs_param_excluded)).to be false
    end

    it 'returns false if the avs param is nil' do
      expect(subject.send(:avs_applicable?, past_appointment, nil)).to be false
    end
  end

  describe '#normalize_icn' do
    context 'when icn is nil' do
      it 'returns nil' do
        expect(subject.send(:normalize_icn, nil)).to be_nil
      end
    end

    context 'when icn is an empty string' do
      it 'returns an empty string' do
        expect(subject.send(:normalize_icn, '')).to eq('')
      end
    end

    context 'when icn does not end with "V" followed by six digits' do
      icn = '123456AA789012'

      it 'returns the same icn' do
        expect(subject.send(:normalize_icn, icn)).to eq(icn)
      end
    end

    context 'when icn ends with "V" followed by six digits' do
      icn = '1234567890V654321'

      it 'removes trailing "V" followed by six digits' do
        expect(subject.send(:normalize_icn, icn)).to eq('1234567890')
      end
    end
  end

  describe '#icns_match?' do
    context 'when either icn is nil' do
      it 'returns false' do
        expect(subject.send(:icns_match?, nil, '1234567890V123456')).to be(false)
        expect(subject.send(:icns_match?, '1234567890V123456', nil)).to be(false)
      end
    end

    context 'when both icns are not nil and match' do
      it 'returns true' do
        expect(subject.send(:icns_match?, '1234567890V654321', '1234567890V654321')).to be(true)
      end
    end

    context 'when both icns are not nil and do not match' do
      it 'returns false' do
        expect(subject.send(:icns_match?, '1234567890V123456', '1234567899V123456')).to be(false)
      end
    end
  end

  describe '#get_avs_link' do
    let(:user) { build(:user, :loa3, :legacy_icn) }
    let(:expected_avs_link) do
      '/my-health/medical-records/summaries-and-notes/visit-summary/9A7AF40B2BC2471EA116891839113252'
    end
    let(:appt) do
      {
        identifier: [
          {
            system: 'Appointment/',
            value: '4139383338323131'
          },
          {
            system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_84',
            value: '500:9876543'
          }
        ],
        ien: '9876543',
        station: '500'
      }
    end

    context 'with good station number and ien' do
      it 'returns avs link' do
        VCR.use_cassette('vaos/v2/appointments/avs-search-9876543', match_requests_on: %i[method path query]) do
          expect(subject.send(:get_avs_link, appt)).to eq(expected_avs_link)
        end
      end
    end

    context 'with mismatched icn' do
      it 'returns nil and logs mismatch' do
        VCR.use_cassette('vaos/v2/appointments/avs-search-9876543', match_requests_on: %i[method path query]) do
          allow(Rails.logger).to receive(:warn)
          user.identity.icn = '123'

          expect(subject.send(:get_avs_link, appt)).to be_nil
          expect(Rails.logger).to have_received(:warn).with('VAOS: AVS response ICN does not match user ICN')
        end
      end
    end

    context 'with non-hash body' do
      it 'returns nil' do
        VCR.use_cassette('vaos/v2/appointments/avs-search-error', match_requests_on: %i[method path query]) do
          expect(subject.send(:get_avs_link, appt)).to be_nil
        end
      end
    end
  end

  describe '#fetch_avs_and_update_appt_body' do
    let(:avs_resp) { double(body: [{ icn: '1012846043V576341', sid: '12345' }], status: 200) }
    let(:avs_link) { '/my-health/medical-records/summaries-and-notes/visit-summary/12345' }
    let(:avs_pdf) do
      [
        {
          'appt_id' => '12345',
          'id' => '15249638961',
          'name' => 'Ambulatory Visit Summary',
          'loinc_codes' => %w[4189669 96345-4],
          'note_type' => 'ambulatory_patient_summary',
          'content_type' => 'application/pdf'
        }
      ]
    end
    let(:appt_cerner) do
      { id: '12345', identifier: [{ system: 'urn:va.gov:masv2:cerner:appointment', value: 'Appointment/1234567' }],
        ien: '12345678', station: '983' }
    end
    let(:appt_vista) do
      { id: '12345', identifier: [{ system: '/Terminology/VistADefinedTerms/409_84', value: '983:12345678' }],
        ien: '12345678', station: '983' }
    end
    let(:avs_error) { 'Error retrieving AVS info' }

    context 'OH AVS PDF' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_add_OH_avs).and_return(true)
      end

      context 'when UHD Service successfully retrieved the AVS PDF' do
        it 'fetches the AVS PDF and updates the appt hash' do
          allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_appt_avs).and_return(avs_pdf)
          subject.send(:fetch_avs_and_update_appt_body, appt_cerner)
          expect(appt_cerner[:avs_pdf]).to eq(avs_pdf)
        end
      end

      context 'when an error occurs while retrieving AVS PDF' do
        it 'logs the error and sets the avs_error field to an error message' do
          allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_appt_avs)
            .and_raise(Common::Exceptions::BackendServiceException)
          expect(Rails.logger).to receive(:error)
          subject.send(:fetch_avs_and_update_appt_body, appt_cerner)
          expect(appt_cerner[:avs_error]).to eq(avs_error)
          expect(appt_cerner[:avs_pdf]).to be_nil
          expect(appt_cerner[:avs_path]).to be_nil
        end
      end

      context 'when there is no available after visit summary pdf for the appointment' do
        let(:user) { build(:user, :vaos) }

        it 'returns an avs error message field in the appointment response' do
          allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_appt_avs).and_return([])
          subject.send(:fetch_avs_and_update_appt_body, appt_cerner)
          expect(appt_cerner[:avs_pdf]).to be_nil
        end
      end

      context 'when processing cerner appointment but flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_add_OH_avs).and_return(false)
        end

        it 'does not fetch the OH AVS' do
          subject.send(:fetch_avs_and_update_appt_body, appt_cerner)
          expect(appt_cerner[:avs_pdf]).to be_nil
        end
      end
    end

    context 'AVS Link' do
      context 'when AVS successfully retrieved the AVS link' do
        it 'fetches the avs link and updates the appt hash' do
          allow_any_instance_of(Avs::V0::AvsService).to receive(:get_avs_by_appointment).and_return(avs_resp)
          subject.send(:fetch_avs_and_update_appt_body, appt_vista)
          expect(appt_vista[:avs_path]).to eq(avs_link)
        end
      end

      context 'when an error occurs while retrieving AVS link' do
        it 'logs the error and sets the avs_path to an error message' do
          allow_any_instance_of(Avs::V0::AvsService).to receive(:get_avs_by_appointment)
            .and_raise(Common::Exceptions::BackendServiceException)
          expect(Rails.logger).to receive(:error)
          subject.send(:fetch_avs_and_update_appt_body, appt_vista)
          expect(appt_vista[:avs_error]).to eq(avs_error)
          expect(appt_vista[:avs_path]).to be_nil
        end
      end

      context 'when there is no available after visit summary for the appointment' do
        let(:user) { build(:user, :vaos) }
        let(:appt_no_avs) { { id: '192308' } }

        it 'returns an avs error message field in the appointment response' do
          subject.send(:fetch_avs_and_update_appt_body, appt_no_avs)
          expect(appt_no_avs[:avs_path]).to be_nil
        end
      end
    end
  end

  describe '#fetch_avs_binaries' do
    let(:avs_pdf) do
      UnifiedHealthData::BinaryData.new(
        content_type: 'application/pdf',
        binary: 'binaryString'
      )
    end

    context 'invalid arguments' do
      it 'sets the error field when doc_id is nil' do
        result = subject.send(:fetch_avs_binaries, 'appt', [nil])
        expect(result).to eq([{
                               doc_id: nil,
                               error: 'Retrieved empty AVS binary'
                             }])
      end

      it 'returns nil when appt_id is nil' do
        result = subject.send(:fetch_avs_binaries, nil, ['doc1'])
        expect(result).to be_nil
      end

      it 'returns nil when doc_ids is nil' do
        result = subject.send(:fetch_avs_binaries, 'appt', nil)
        expect(result).to be_nil
      end

      it 'returns nil when doc_ids is empty' do
        result = subject.send(:fetch_avs_binaries, 'appt', [])
        expect(result).to be_nil
      end
    end

    context 'when UHD Service successfully retrieved the binaries' do
      it 'returns the fetched PDF binaries' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_avs_binary_data)
          .with(doc_id: 'doc1', appt_id: 'appt').and_return(avs_pdf)
        result = subject.send(:fetch_avs_binaries, 'appt', ['doc1'])
        expect(result).to eq([{
                               doc_id: 'doc1',
                               binary: 'binaryString'
                             }])
      end
    end

    context 'when an error occurs' do
      it 'logs the error and sets the error field' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_avs_binary_data)
          .with(doc_id: 'doc1', appt_id: 'appt')
          .and_raise(Common::Exceptions::BackendServiceException)
        expect(Rails.logger).to receive(:error)
        result = subject.send(:fetch_avs_binaries, 'appt', ['doc1'])
        expect(result).to eq([{
                               doc_id: 'doc1',
                               error: 'Error retrieving AVS binary'
                             }])
      end
    end

    context 'when there is no available binary' do
      it 'sets the error field' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_avs_binary_data)
          .with(doc_id: 'doc1', appt_id: 'appt').and_return(nil)
        result = subject.send(:fetch_avs_binaries, 'appt', ['doc1'])
        expect(result).to eq([{
                               doc_id: 'doc1',
                               error: 'Retrieved empty AVS binary'
                             }])
      end
    end

    context 'when there are mixed results' do
      it 'returns both successful binaries and error fields' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_avs_binary_data)
          .with(doc_id: 'doc1', appt_id: 'appt').and_return(avs_pdf)
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_avs_binary_data)
          .with(doc_id: 'doc2', appt_id: 'appt')
          .and_raise(Common::Exceptions::BackendServiceException)
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_avs_binary_data)
          .with(doc_id: 'doc3', appt_id: 'appt').and_return(nil)

        expect(Rails.logger).to receive(:error)
        result = subject.send(:fetch_avs_binaries, 'appt', %w[doc1 doc2 doc3])
        expect(result).to eq([
                               {
                                 doc_id: 'doc1',
                                 binary: 'binaryString'
                               },
                               {
                                 doc_id: 'doc2',
                                 error: 'Error retrieving AVS binary'
                               },
                               {
                                 doc_id: 'doc3',
                                 error: 'Retrieved empty AVS binary'
                               }
                             ])
      end
    end
  end

  describe '#filter_reason_code_text' do
    let(:request_object_body) { { reason_code: { text: "This is\t a test\n\r" } } }
    let(:request_object_body_with_non_ascii) { { reason_code: { text: 'Thïs ïs ä tést' } } }
    let(:request_object_body_without_text) { { reason_code: {} } }

    context 'when the request object body reason code text contains ASCII characters only' do
      it 'returns the same text' do
        expect(subject.send(:filter_reason_code_text, request_object_body)).to eq("This is\t a test\n\r")
      end
    end

    context 'when the request object body reason code text contains non-ASCII characters' do
      it 'returns the text with non-ASCII characters filtered out' do
        expect(subject.send(:filter_reason_code_text, request_object_body_with_non_ascii)).to eq('Ths s  tst')
      end
    end

    context 'when the request object body reason code does not contain a text field' do
      it 'returns nil' do
        expect(subject.send(:filter_reason_code_text, request_object_body_without_text)).to be_nil
      end
    end

    context 'when nil is passed in for the request object body' do
      it 'returns nil' do
        expect(subject.send(:filter_reason_code_text, nil)).to be_nil
      end
    end
  end

  describe '#page_params' do
    context 'when per_page is positive' do
      context 'when per_page is positive' do
        let(:pagination_params) do
          { per_page: 3, page: 2 }
        end

        it 'returns pageSize and page' do
          result = subject.send(:page_params, pagination_params)

          expect(result).to eq({ pageSize: 3, page: 2 })
        end
      end
    end

    context 'when per_page is not positive' do
      let(:pagination_params) do
        { per_page: 0, page: 2 }
      end

      it 'returns pageSize only' do
        result = subject.send(:page_params, pagination_params)

        expect(result).to eq({ pageSize: 0 })
      end
    end

    context 'when per_page does not exist' do
      let(:pagination_params) do
        { page: 2 }
      end

      it 'returns pageSize as 0' do
        result = subject.send(:page_params, pagination_params)

        expect(result).to eq({ pageSize: 0 })
      end
    end
  end

  describe '#add_timezone_offset' do
    let(:desired_date) { '2022-09-21T00:00:00+00:00'.to_datetime }

    context 'with a date and timezone' do
      it 'adds the timezone offset to the date' do
        date_with_offset = subject.send(:add_timezone_offset, desired_date, 'America/New_York')
        expect(date_with_offset.to_s).to eq('2022-09-21T00:00:00-04:00')
      end
    end

    context 'with a date and nil timezone' do
      it 'leaves the date as is' do
        date_with_offset = subject.send(:add_timezone_offset, desired_date, nil)
        expect(date_with_offset.to_s).to eq(desired_date.to_s)
      end
    end

    context 'with a nil date' do
      it 'throws a ParameterMissing exception' do
        expect do
          subject.send(:add_timezone_offset, nil, 'America/New_York')
        end.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end
  end

  describe '#modify_desired_date' do
    let(:va_booked_request_body) do
      build(:appointment_form_v2, :va_booked).attributes
    end

    context 'with a request body and facility timezone' do
      it 'updates the direct scheduled appt desired date with facilities time zone offset' do
        subject.send(:modify_desired_date, va_booked_request_body, 'America/Denver')
        expect(va_booked_request_body[:extension][:desired_date].to_s).to eq('2022-11-30T00:00:00-07:00')
      end
    end
  end

  describe '#extract_appointment_fields' do
    it 'do not overwrite existing preferred dates' do
      # Note that the va_proposed appointment here contains both a reason code text and
      # requested periods which will not occur in a real scenario. However the example
      # demonstrates that the preferred dates from reason code text are not overwritten.
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text, user:).attributes
      subject.send(:extract_appointment_fields, appt)
      expect(appt[:preferred_dates]).to eq(['Wednesday, June 26, 2024 in the morning',
                                            'Wednesday, June 26, 2024 in the afternoon'])
    end

    it 'extracts preferred dates if possible' do
      appt = build(:appointment_form_v2, :community_cares_multiple_request_dates, user:).attributes
      subject.send(:extract_appointment_fields, appt)
      expect(appt[:preferred_dates]).to eq(['Wednesday, August 28, 2024 in the morning',
                                            'Wednesday, August 28, 2024 in the afternoon'])
    end

    it 'do not extract preferred dates if no requested periods' do
      appt = build(:appointment_form_v2, :community_cares_no_request_dates, user:).attributes
      subject.send(:extract_appointment_fields, appt)
      expect(appt[:preferred_dates]).to be_nil
    end
  end

  describe '#extract_request_preferred_dates' do
    let(:appt_no_req_periods) do
      { id: '12345', requestedPeriods: [{ start: nil, end: nil }] }
    end

    it 'does not extract when requested period start is nil' do
      subject.send(:extract_request_preferred_dates, appt_no_req_periods)
      expect(appt_no_req_periods[:preferred_dates]).to be_nil
    end

    it 'extracts when requested period start is present' do
      appt = build(:appointment_form_v2, :community_cares_multiple_request_dates, user:).attributes
      subject.send(:extract_request_preferred_dates, appt)
      expect(appt[:preferred_dates]).not_to be_nil
    end
  end

  describe '#set_telehealth_visibility' do
    let(:current_time) { '2022-09-21T12:00:00+00:00'.to_datetime }

    before do
      Timecop.freeze(current_time)
      allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(false)
    end

    after do
      Timecop.unfreeze
    end

    it 'sets telehealth visibility to nil if appointment is not a telehealth type' do
      appt = appt_med
      subject.send(:set_telehealth_visibility, appt)
      expect(appt.dig(:telehealth, :display_link)).to be_nil
    end

    it 'sets telehealth visibility to true if current time is 30 minutes before start time' do
      appt = build(:appointment_form_v2, :telehealth).attributes
      appt[:start] = '2022-09-21T12:30:00+00:00'.to_datetime
      appt[:modality] = 'vaVideoCareAtHome'
      subject.send(:set_telehealth_visibility, appt)
      expect(appt.dig(:telehealth, :display_link)).to be(true)
    end

    it 'sets telehealth visibility to true if current time is within 4 hours of start time' do
      appt = build(:appointment_form_v2, :telehealth).attributes
      appt[:start] = '2022-09-21T08:00:00+00:00'.to_datetime
      appt[:modality] = 'vaVideoCareAtHome'
      subject.send(:set_telehealth_visibility, appt)
      expect(appt.dig(:telehealth, :display_link)).to be(true)
    end

    it 'sets telehealth visibility to false if current time is more than 30 minutes from start time' do
      appt = build(:appointment_form_v2, :telehealth).attributes
      appt[:start] = '2022-09-21T12:31:00+00:00'.to_datetime
      appt[:modality] = 'vaVideoCareAtHome'
      subject.send(:set_telehealth_visibility, appt)
      expect(appt.dig(:telehealth, :display_link)).to be(false)
    end

    it 'sets telehealth visibility to false if current time is more than 4 hours from start time' do
      appt = build(:appointment_form_v2, :telehealth).attributes
      appt[:start] = '2022-09-21T07:59:00+00:00'.to_datetime
      appt[:modality] = 'vaVideoCareAtHome'
      subject.send(:set_telehealth_visibility, appt)
      expect(appt.dig(:telehealth, :display_link)).to be(false)
    end
  end

  describe '#set_modality' do
    it 'is vaInPersonVaccine for covid service_type' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:service_type] = 'covid'
      subject.send(:set_modality, appt)
      expect(appt[:modality]).to eq('vaInPersonVaccine')
    end

    it 'is vaInPerson for clinic kind' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      subject.send(:set_modality, appt)
      expect(appt[:modality]).to eq('vaInPerson')
    end

    it 'is vaVideoCareAtAVaLocation for CLINIC_BASED vvsKind' do
      appt = build(:appointment_form_v2, :telehealth).attributes
      subject.send(:set_modality, appt)
      expect(appt[:modality]).to eq('vaVideoCareAtAVaLocation')
    end

    it 'is vaVideoCareAtAVaLocation for STORE_FORWARD vvsKind' do
      appt = build(:appointment_form_v2, :telehealth).attributes
      appt[:telehealth][:vvs_kind] = 'STORE_FORWARD'
      subject.send(:set_modality, appt)
      expect(appt[:modality]).to eq('vaVideoCareAtAVaLocation')
    end

    %w[ADHOC MOBILE_ANY MOBILE_ANY_GROUP MOBILE_GFE].each do |input|
      it "is vaVideoCareAtHome for #{input} vvsKind" do
        appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text, :telehealth).attributes
        appt[:telehealth][:vvs_kind] = input
        subject.send(:set_modality, appt)
        expect(appt[:modality]).to eq('vaVideoCareAtHome')
      end
    end

    it 'is vaInPerson for nil vvsKind, non-cerner and false vvsVistaVideoAppt' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text, :telehealth, :vistaVideoFalse).attributes
      appt[:telehealth][:vvs_kind] = nil
      subject.send(:set_modality, appt)
      expect(appt[:modality]).to eq('vaInPerson')
    end

    it 'is vaVideoCareAtHome for nil vvsKind, non-cerner and true vvsVistaVideoAppt' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text, :telehealth, :vistaVideoTrue).attributes
      appt[:telehealth][:vvs_kind] = nil
      subject.send(:set_modality, appt)
      expect(appt[:modality]).to eq('vaVideoCareAtHome')
    end

    it 'is vaInPerson for nil vvsKind, cerner and url not available' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text, :cerner_telehealth).attributes
      appt[:identifier] = [
        {
          system: 'urn:va.gov:masv2:cerner:appointment',
          value: 'Appointment/52499028'
        }
      ]
      subject.send(:set_modality, appt)
      expect(appt[:kind]).to eq('telehealth')
      expect(appt.dig(:telehealth, :vvs_kind)).to be_nil
      expect(VAOS::AppointmentsHelper.cerner?(appt)).to be(true)
      expect(appt.dig(:telehealth, :url)).to be_nil
      expect(appt[:modality]).to eq('vaInPerson')
    end

    it 'is vaVideoCareAtHome for nil vvsKind, cerner and url available' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text, :cerner_telehealth_url).attributes
      appt[:identifier] = [
        {
          system: 'urn:va.gov:masv2:cerner:appointment',
          value: 'Appointment/52499028'
        }
      ]
      subject.send(:set_modality, appt)
      expect(appt[:kind]).to eq('telehealth')
      expect(appt.dig(:telehealth, :vvs_kind)).to be_nil
      expect(VAOS::AppointmentsHelper.cerner?(appt)).to be(true)
      expect(appt.dig(:telehealth, :url)).not_to be_nil
      expect(appt[:modality]).to eq('vaVideoCareAtHome')
    end

    it 'is nil for unrecognized vvsKind' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text, :telehealth).attributes
      appt[:telehealth][:vvs_kind] = 'MOBILE_UNKNOWN'
      subject.send(:set_modality, appt)
      expect(appt[:modality]).to be_nil
    end

    it 'is vaVideoCareAtAnAtlasLocation for telehealth appointment with atlas' do
      appt = build(:appointment_form_v2, :telehealth).attributes
      appt[:telehealth][:atlas] = {}
      subject.send(:set_modality, appt)
      expect(appt[:modality]).to eq('vaVideoCareAtAnAtlasLocation')
    end

    it 'is vaPhone for phone kind' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:kind] = 'phone'
      subject.send(:set_modality, appt)
      expect(appt[:modality]).to eq('vaPhone')
    end

    it 'is claimExamAppointment for comp & pen service_category' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:service_category] = [{ text: 'COMPENSATION & PENSION' }]
      subject.send(:set_modality, appt)
      expect(appt[:modality]).to eq('claimExamAppointment')
    end

    it 'is communityCare for cc kind' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:kind] = 'cc'
      subject.send(:set_modality, appt)
      expect(appt[:modality]).to eq('communityCare')
    end

    it 'logs failure to determine modality' do
      allow(Rails.logger).to receive(:warn).at_least(:once)
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:kind] = 'none'
      subject.send(:set_modality, appt)
      expect(appt[:modality]).to be_nil
      expect(Rails.logger).to have_received(:warn).at_least(:once)
    end

    it 'requires appointment' do
      expect do
        subject.send(:set_modality)
      end.to raise_error(ArgumentError)
    end
  end

  describe '#request' do
    it 'sets pending to true if the appointment is a request' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:type] = 'REQUEST'
      expect(subject.send(:request?, appt)).to be(true)
    end

    it 'sets pending to true if the appointment is a community-care request' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:type] = 'COMMUNITY_CARE_REQUEST'
      expect(subject.send(:request?, appt)).to be(true)
    end

    it 'sets pending to false if the appointment is not a request' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:type] = 'VA'
      expect(subject.send(:request?, appt)).to be(false)
    end

    it 'requires appointment' do
      expect do
        subject.send(:request?, nil)
      end.to raise_error(ArgumentError)
    end
  end

  describe '#past' do
    it 'sets past to true if the appointment is telehealth and within 240 minutes' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:kind] = 'telehealth'
      appt[:start] = Time.now.utc - 241.minutes
      expect(subject.send(:past?, appt)).to be(true)
    end

    it 'sets past to false if the appointment is telehealth and not within 240 minutes' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:kind] = 'telehealth'
      appt[:start] = Time.now.utc - 239.minutes
      expect(subject.send(:past?, appt)).to be(false)
    end

    it 'sets past to true if the appointment is not telehealth and within 60 minutes' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:kind] = 'clinic'
      appt[:start] = Time.now.utc - 61.minutes
      expect(subject.send(:past?, appt)).to be(true)
    end

    it 'sets past to false if the appointment is not telehealth and not within 60 minutes' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:kind] = 'clinic'
      appt[:start] = Time.now.utc - 59.minutes
      expect(subject.send(:past?, appt)).to be(false)
    end

    it 'requires appointment' do
      expect do
        subject.send(:past?, nil)
      end.to raise_error(ArgumentError)
    end
  end

  describe '#future' do
    it 'sets future to true if the appointment is not a request and occurs within the past 60 minutes' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:type] = 'VA'
      appt[:start] = Time.now.utc - 30.minutes
      expect(subject.send(:future?, appt)).to be(true)
    end

    it 'sets future to true if the appointment is telehealth and occurs within the past 240 minutes' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:type] = 'VA'
      appt[:kind] = 'telehealth'
      appt[:start] = Time.now.utc - 210.minutes
      expect(subject.send(:future?, appt)).to be(true)
    end

    it 'sets future to true if the appointment is not a request and occurs after the beginning of the current day' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:type] = 'VA'
      appt[:start] = Time.now.utc + 1.day
      expect(subject.send(:future?, appt)).to be(true)
    end

    it 'sets future to false if the appointment is not a request and occurs before the beginning of the current day' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:type] = 'VA'
      appt[:start] = Time.now.utc - 1.day
      expect(subject.send(:future?, appt)).to be(false)
    end

    it 'sets future to false if the appointment is a request' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:type] = 'REQUEST'
      appt[:start] = Time.now.utc + 1.day
      expect(subject.send(:future?, appt)).to be(false)
    end

    it 'requires appointment' do
      expect do
        subject.send(:future?, nil)
      end.to raise_error(ArgumentError)
    end
  end

  describe '#set_type' do
    it 'has a type of request for Cerner appointments without end dates' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:id] = 'CERN1234'
      appt[:identifier] = [
        {
          system: 'urn:va.gov:masv2:cerner:appointment',
          value: 'Appointment/52499028'
        }
      ]
      appt[:end] = nil
      subject.send(:set_type, appt)
      expect(appt[:type]).to eq('REQUEST')
    end

    it 'is a VA appointment for Cerner appointments with a valid end date' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:id] = 'CERN1234'
      appt[:identifier] = [
        {
          system: 'urn:va.gov:masv2:cerner:appointment',
          value: 'Appointment/52499028'
        }
      ]
      appt[:end] = :end_date
      subject.send(:set_type, appt)
      expect(appt[:type]).to eq('VA')
    end

    it 'is a cc appointment for appointments with kind = "cc" and a valid start date' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:id] = :id
      appt[:start] = :start_date
      appt[:requested_periods] = []
      appt[:kind] = 'cc'
      subject.send(:set_type, appt)
      expect(appt[:type]).to eq('COMMUNITY_CARE_APPOINTMENT')
    end

    it 'is a cc request for appointments with kind = "cc" and at least one requested period' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:id] = :id
      appt[:kind] = 'cc'
      appt[:requested_periods] = [{ start: '2024-06-26T12:00:00Z', end: '2024-06-26T13:00:00Z' }]
      subject.send(:set_type, appt)
      expect(appt[:type]).to eq('COMMUNITY_CARE_REQUEST')
    end

    it 'is a request for appointments with kind other than "cc" and at least one requested period' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:id] = :id
      appt[:kind] = 'telehealth'
      appt[:requested_periods] = [{ start: '2024-06-26T12:00:00Z', end: '2024-06-26T13:00:00Z' }]
      subject.send(:set_type, appt)
      expect(appt[:type]).to eq('REQUEST')
    end

    it 'is a request for appointments with kind = "cc" and no start date or requested periods' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:id] = :id
      appt[:kind] = 'cc'
      appt[:start] = nil
      appt[:requested_periods] = []
      subject.send(:set_type, appt)
      expect(appt[:type]).to eq('COMMUNITY_CARE_APPOINTMENT')
    end

    it 'is a cc request for Cerner with no start date or requested periods' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      appt[:id] = 'CERN1234'
      appt[:identifier] = [
        {
          system: 'urn:va.gov:masv2:cerner:appointment',
          value: 'Appointment/52499028'
        }
      ]
      appt[:kind] = 'cc'
      appt[:start] = nil
      appt[:requested_periods] = []
      subject.send(:set_type, appt)
      expect(appt[:type]).to eq('COMMUNITY_CARE_REQUEST')
    end
  end

  describe '#schedulable?' do
    it 'returns false for CERNER appointments' do
      appt = build(:appointment_form_v2, :va_cancelled_valid_reason_code_text).attributes
      appt[:id] = 'CERN1234'
      subject.send(:set_type, appt)
      expect(subject.send(:schedulable?, appt)).to be(false)
    end

    it 'returns false for claims exam appointments' do
      appt = build(:appointment_form_v2, :va_cancelled_valid_reason_code_text).attributes
      appt[:id] = '1234'
      appt[:service_category] = [{ text: 'COMPENSATION & PENSION' }]
      subject.send(:set_type, appt)
      expect(subject.send(:schedulable?, appt)).to be(false)
    end

    it 'returns false for telehealth appointments' do
      appt = build(:appointment_form_v2, :va_cancelled_valid_reason_code_text).attributes
      appt[:id] = '1234'
      appt[:kind] = 'telehealth'
      subject.send(:set_type, appt)
      expect(subject.send(:schedulable?, appt)).to be(false)
    end

    it 'returns false for cc appointment' do
      appt = build(:appointment_form_v2, :community_cares_no_request_dates).attributes
      appt[:id] = '1234'
      subject.send(:set_type, appt)
      expect(subject.send(:schedulable?, appt)).to be(false)
    end

    it 'returns true for cc request' do
      appt = build(:appointment_form_v2, :community_cares_base).attributes
      appt[:id] = '1234'
      subject.send(:set_type, appt)
      expect(subject.send(:schedulable?, appt)).to be(true)
    end

    it 'returns true for va requests' do
      appt = build(:appointment_form_v2, :va_proposed_base).attributes
      appt[:id] = '1234'
      subject.send(:set_type, appt)
      expect(subject.send(:schedulable?, appt)).to be(true)
    end

    context 'returns true for schedulable service' do
      %w[
        primaryCare
        clinicalPharmacyPrimaryCare
        outpatientMentalHealth
        socialWork
        amputation
        audiology
        moveProgram
        foodAndNutrition
        optometry
        ophthalmology
        cpap
        homeSleepTesting
        covid
      ].each do |service|
        it service.to_s do
          appt = build(:appointment_form_v2, :va_cancelled_valid_reason_code_text).attributes
          appt[:id] = '1234'
          appt[:service_type] = service
          subject.send(:set_type, appt)
          expect(subject.send(:schedulable?, appt)).to be(true)
        end
      end
    end

    context 'returns false for unschedulable service' do
      [
        'podiatry',
        'audiology-routine exam',
        'audiology-hearing aid support'
      ].each do |service|
        it service.to_s do
          appt = build(:appointment_form_v2, :va_cancelled_valid_reason_code_text).attributes
          appt[:id] = '1234'
          appt[:service_type] = service
          subject.send(:set_type, appt)
          expect(subject.send(:schedulable?, appt)).to be(false)
        end
      end
    end
  end
end
