# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::CommunityCare::AppointmentCoordinator do
  subject { described_class.new(user) }

  let(:user) { build(:user, :jac) }

  before do
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe '#appointments_for_referral' do
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
              result = subject.appointments_for_referral('ref-123')

              mapped_eps = result[:EPS][:data].map { |a| { id: a[:id], status: a[:status], start: a[:start] } }
              expect(mapped_eps).to eq([
                                         { id: 'appt2', status: 'cancelled', start: '2024-11-21T18:00:00Z' },
                                         { id: 'appt1', status: 'active', start: '2024-11-20T17:00:00Z' },
                                         { id: 'appt4', status: 'active', start: '2024-11-19T18:00:00Z' }
                                       ])

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
              result = subject.appointments_for_referral('ref-150')

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
          subject.appointments_for_referral('test-referral-1234')
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
              subject.appointments_for_referral('test-referral-5678')
            end.to raise_error(StandardError)
          end
        end
      end
    end

    context 'when VAOS returns non-array data' do
      it 'returns empty array for VAOS data without crashing and logs warning' do
        appointments_service = VAOS::V2::AppointmentsService.new(user)
        allow(VAOS::V2::AppointmentsService).to receive(:new).and_return(appointments_service)
        allow(appointments_service).to receive(:get_all_appointments)
          .and_return({ data: {}, meta: {} })
        allow(Rails.logger).to receive(:warn)

        VCR.use_cassette('vaos/eps/token/token_200',
                         match_requests_on: %i[method path],
                         allow_playback_repeats: true, tag: :force_utf8) do
          VCR.use_cassette('vaos/eps/get_appointments/200_empty',
                           match_requests_on: %i[method path],
                           allow_playback_repeats: true, tag: :force_utf8) do
            result = subject.appointments_for_referral('test-referral-1234')
            warn_msg = 'VAOS process_vaos_appointments - appointments_data is not an array'
            expect(result[:VAOS][:data]).to eq([])
            expect(Rails.logger).to have_received(:warn).with(warn_msg)
          end
        end
      end
    end
  end

  describe '#referral_already_used?' do
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
              check = subject.referral_already_used?('ref-150')
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
              check = subject.referral_already_used?('ref-122')
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
              check = subject.referral_already_used?('ref124')
              expect(check).to be_a(Hash)
              expect(check[:exists]).to be(true)
              expect(check).not_to have_key(:failure)
            end
          end
        end
      end

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

              check = subject.referral_already_used?('ref-150')
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
          it 'logs missing ICN error and combines with format errors' do
            expected_error = MAP::SecurityToken::Errors::MissingICNError.new 'Missing ICN message'
            allow_any_instance_of(VAOS::SessionService).to receive(:headers).and_raise(expected_error)
            allow(Rails.logger).to receive(:warn).at_least(:once)
            check = subject.referral_already_used?('ref-150')

            expected_message = 'VAOS::V2::AppointmentService#get_all_appointments missing ICN'
            expect(Rails.logger)
              .to have_received(:warn)
              .with(expected_message)
            expect(check[:failures]).to be_a(String)
            expect(check[:failures]).to include('Missing ICN message')
          end
        end
      end

      context 'when get_all_appointments returns non-array data' do
        it 'logs error and returns failure with VAOS_RESPONSE_FORMAT_ERROR' do
          appointments_service = VAOS::V2::AppointmentsService.new(user)
          mock_response = double(body: { data: {} })
          allow(mock_response).to receive(:dig).with(:meta, :failures).and_return(nil)
          allow(appointments_service).to receive(:send_appointments_request).and_return(mock_response)
          allow(VAOS::V2::AppointmentsService).to receive(:new).and_return(appointments_service)
          allow(Rails.logger).to receive(:error)

          result = subject.referral_already_used?('ref-150')

          expect(result[:error]).to be(true)
          expect(result[:failures]).to be_a(String)
          expect(result[:failures]).to include('Unexpected VAOS response')
          expect(Rails.logger).to have_received(:error).with(
            'VAOS::V2::CommunityCare::AppointmentCoordinator#referral_already_used?: ' \
            'Unexpected VAOS response format: data is Hash, expected Array'
          )
        end
      end
    end

    describe 'EPS mock bypass behavior' do
      let(:referral_id) { 'ref124' }

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
              result = subject.referral_already_used?(referral_id)

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
                result = subject.referral_already_used?(referral_id)

                expect(result[:exists]).to be(true)
              end
            end
          end
        end
      end
    end
  end
end
