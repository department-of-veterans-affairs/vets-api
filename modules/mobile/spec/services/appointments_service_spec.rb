# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

describe Mobile::V0::Appointments::Service do
  let(:user) { FactoryBot.build(:iam_user) }
  let(:service) { Mobile::V0::Appointments::Service.new(user) }

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  before do
    iam_sign_in
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    Timecop.freeze(Time.zone.parse('2020-11-01T10:30:00Z'))
  end

  after { Timecop.return }

  describe '#get_appointments' do
    let(:start_date) { Time.now.utc }
    let(:end_date) { start_date + 3.months }

    context 'when both va and cc appointments return 200s' do
      let(:responses) do
        VCR.use_cassette('appointments/get_appointments', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
            service.get_appointments(start_date, end_date)
          end
        end
      end

      it 'returns a 200 for the VA response' do
        expect(responses[:va].status).to eq(200)
      end

      it 'returns a 200 for the CC response' do
        expect(responses[:cc].status).to eq(200)
      end

      it 'has raw appointment data in the va response' do
        expect(responses[:va].body.dig(:data, :appointment_list).first).to eq(
          {
            start_date: '2020-11-03T16:00:00Z',
            clinic_id: '308',
            clinic_friendly_name: 'Green Team Clinic1',
            facility_id: '983',
            sta6aid: '983',
            patient_icn: '1012845331V153043',
            community_care: false,
            vds_appointments: [{ appointment_length: '20',
                                 appointment_time: '2020-11-03T16:00:00Z',
                                 clinic: { name: 'CHY PC KILPATRICK', ask_for_check_in: false, facility_code: '983' },
                                 patient_id: '7216691',
                                 type: 'SERVICE CONNECTED',
                                 current_status: 'FUTURE' }]
          }
        )
      end

      it 'has raw appointment data in the cc response' do
        expect(responses[:cc].body[:booked_appointment_collections].first[:booked_cc_appointments].first).to eq(
          {
            appointment_request_id: '8a4885896a22f88f016a2c8834b1012d',
            patient_identifier: { unique_id: '1012845331V153113', assigning_authority: 'ICN' },
            distance_eligible_confirmed: true,
            name: { first_name: '', last_name: '' },
            provider_practice: 'Atlantic Medical Care',
            provider_phone: '(407) 555-1212',
            address: { street: '123 Main Street', city: 'Orlando', state: 'FL', zip_code: '32826' },
            instructions_to_veteran: 'Please arrive 15 minutes ahead of appointment.',
            appointment_time: '11/25/2020 13:30:00',
            time_zone: '-11:00 EDT'
          }
        )
      end

      it 'increments the VAOS and Mobile success metrics' do
        expect(StatsD).to receive(:increment).once.with(
          'api.external_http_request.VAOS.success',
          1,
          { tags: [
            'endpoint:/appointments/v1/patients/xxx/appointments',
            'method:get'
          ] }
        )
        expect(StatsD).to receive(:increment).once.with(
          'api.external_http_request.VAOS.success',
          1,
          { tags: [
            'endpoint:/var/VeteranAppointmentRequestService/v4/rest'\
'/direct-scheduling/patient/ICN/xxx/booked-cc-appointments',
            'method:get'
          ] }
        )
        expect(StatsD).to receive(:increment).once.with(
          'mobile.appointments.service.get_appointments.success',
          { no_prefix: false, prefix: nil, sample_rate: nil, tags: nil }
        )
        VCR.use_cassette('appointments/get_appointments', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
            service.get_appointments(start_date, end_date)
          end
        end
      end
    end

    context 'when va fails but cc succeeds' do
      it 'does not return partial results and instead raises a backend service exception' do
        expect(StatsD).to receive(:increment).once.with(
          'api.external_http_request.VAOS.success',
          1,
          { tags: [
            'endpoint:/var/VeteranAppointmentRequestService/v4/rest'\
'/direct-scheduling/patient/ICN/xxx/booked-cc-appointments',
            'method:get'
          ] }
        )
        expect(StatsD).to receive(:increment).once.with(
          'mobile.appointments.service.get_appointments.failure',
          { no_prefix: false, prefix: nil, sample_rate: nil, tags: nil }
        )
        VCR.use_cassette('appointments/get_appointments_500', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
            expect(Rails.logger).to receive(:error).with('mobile get va appointments call failed')
            expect { service.get_appointments(start_date, end_date) }
              .to raise_error(Common::Exceptions::BackendServiceException) do |error|
              expect(error.status_code).to eq(502)
            end
          end
        end
      end
    end

    context 'when va succeeds but cc fails' do
      it 'does not return partial results and instead raises a backend service exception' do
        expect(StatsD).to receive(:increment).once.with(
          'api.external_http_request.VAOS.success',
          1,
          {
            tags: [
              'endpoint:/appointments/v1/patients/xxx/appointments',
              'method:get'
            ]
          }
        )
        expect(StatsD).to receive(:increment).once.with(
          'mobile.appointments.service.get_appointments.failure',
          { no_prefix: false, prefix: nil, sample_rate: nil, tags: nil }
        )
        VCR.use_cassette('appointments/get_appointments', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_500', match_requests_on: %i[method uri]) do
            expect(Rails.logger).to receive(:error).with('mobile get community care appointments call failed')
            expect { service.get_appointments(start_date, end_date) }
              .to raise_error(Common::Exceptions::BackendServiceException) do |error|
              expect(error.status_code).to eq(502)
            end
          end
        end
      end
    end

    context 'when both fail' do
      it 'raises a backend service exception' do
        # VAOS uses success and total rather than success failure
        # so only the statsd call for mobile, added via the gem's meta programming, will fire
        expect(StatsD).to receive(:increment).once.with(
          'mobile.appointments.service.get_appointments.failure',
          { no_prefix: false, prefix: nil, sample_rate: nil, tags: nil }
        )
        VCR.use_cassette('appointments/get_appointments_500', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_500', match_requests_on: %i[method uri]) do
            expect(Rails.logger).to receive(:error).with('mobile get community care appointments call failed')
            expect(Rails.logger).to receive(:error).with('mobile get va appointments call failed')
            expect { service.get_appointments(start_date, end_date) }
              .to raise_error(Common::Exceptions::BackendServiceException) do |error|
              expect(error.status_code).to eq(502)
            end
          end
        end
      end
    end
  end
end
