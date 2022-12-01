# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe Mobile::V0::PreCacheAppointmentsJob, type: :job do
  before do
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    iam_sign_in
    Sidekiq::Worker.clear_all
  end

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  let(:user) { FactoryBot.build(:iam_user) }

  describe '.perform_async' do
    before do
      Timecop.freeze(Time.zone.parse('2020-11-01T10:30:00Z'))
      # turning off mobile_appointment_requests to simplify the test setup
      Flipper.disable(:mobile_appointment_requests)
      Flipper.disable(:mobile_appointment_use_VAOS_MFS)
      Flipper.disable(:mobile_appointment_use_VAOS_v2)
    end

    after { Timecop.return }

    context 'with no errors' do
      it 'caches the expected appointments' do
        VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_default', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_default', match_requests_on: %i[method uri]) do
              expect(Mobile::V0::Appointment.get_cached(user)).to be_nil
              subject.perform(user.uuid)

              first_appointment = Mobile::V0::Appointment.get_cached(user).first.to_h
              expect(
                first_appointment
              ).to eq({ id: '8a488f546b8c0332016b9061d9110006',
                        appointment_type: 'COMMUNITY_CARE',
                        cancel_id: nil,
                        comment: '',
                        facility_id: nil,
                        sta6aid: nil,
                        healthcare_provider: 'Tes',
                        healthcare_service: 'RR',
                        location: { id: nil,
                                    name: 'RR',
                                    address: { street: 'clarksburg', city: 'md', state: 'MD',
                                               zip_code: '22222' },
                                    lat: nil,
                                    long: nil,
                                    phone: { area_code: '301', number: '916-1234', extension: nil },
                                    url: nil,
                                    code: nil },
                        minutes_duration: 60,
                        phone_only: false,
                        start_date_local: '2020-06-26T22:19:00.000-04:00',
                        start_date_utc: '2020-06-27T02:19:00.000Z',
                        status: 'BOOKED',
                        status_detail: nil,
                        time_zone: 'America/New_York',
                        vetext_id: nil,
                        reason: nil,
                        is_covid_vaccine: false,
                        is_pending: false,
                        proposed_times: nil,
                        type_of_care: nil,
                        patient_phone_number: nil,
                        patient_email: nil,
                        best_time_to_call: nil,
                        friendly_location_name: nil })
            end
          end
        end
      end
    end

    context 'with mfs facilities' do
      before { Flipper.enable(:mobile_appointment_use_VAOS_MFS) }

      after { Flipper.disable(:mobile_appointment_use_VAOS_MFS) }

      it 'caches the expected appointments' do
        VCR.use_cassette('appointments/get_mfs_facilities', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_default', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_default', match_requests_on: %i[method uri]) do
              expect(Mobile::V0::Appointment.get_cached(user)).to be_nil
              subject.perform(user.uuid)

              first_appointment = Mobile::V0::Appointment.get_cached(user).first.to_h
              expect(
                first_appointment
              ).to eq({ id: '8a488f546b8c0332016b9061d9110006',
                        appointment_type: 'COMMUNITY_CARE',
                        cancel_id: nil,
                        comment: '',
                        facility_id: nil,
                        sta6aid: nil,
                        healthcare_provider: 'Tes',
                        healthcare_service: 'RR',
                        location: { id: nil,
                                    name: 'RR',
                                    address: { street: 'clarksburg', city: 'md', state: 'MD',
                                               zip_code: '22222' },
                                    lat: nil,
                                    long: nil,
                                    phone: { area_code: '301', number: '916-1234', extension: nil },
                                    url: nil,
                                    code: nil },
                        minutes_duration: 60,
                        phone_only: false,
                        start_date_local: '2020-06-26T22:19:00.000-04:00',
                        start_date_utc: '2020-06-27T02:19:00.000Z',
                        status: 'BOOKED',
                        status_detail: nil,
                        time_zone: 'America/New_York',
                        vetext_id: nil,
                        reason: nil,
                        is_covid_vaccine: false,
                        is_pending: false,
                        proposed_times: nil,
                        type_of_care: nil,
                        patient_phone_number: nil,
                        patient_email: nil,
                        best_time_to_call: nil,
                        friendly_location_name: nil })
            end
          end
        end
      end
    end

    context 'with at home video appointment with no location' do
      it 'caches the expected appointments' do
        VCR.use_cassette('appointments/get_cc_appointments_empty', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_appointments_at_home_no_location',
                           match_requests_on: %i[method uri]) do
            expect(Mobile::V0::Appointment.get_cached(user)).to be_nil
            subject.perform(user.uuid)
            appointment = Mobile::V0::Appointment.get_cached(user).first.to_h

            expect(appointment[:appointment_type]).to eq('VA_VIDEO_CONNECT_HOME')
            expect(appointment[:location]).to eq(
              { id: nil,
                name: 'No location provided',
                address: { street: nil, city: nil, state: nil, zip_code: nil },
                lat: nil,
                long: nil,
                phone: nil,
                url: 'https://care2.evn.va.gov',
                code: '6792040429#' }
            )
          end
        end
      end
    end

    context 'with mobile_precache_appointments flag off' do
      before { Flipper.disable(:mobile_precache_appointments) }

      after { Flipper.enable(:mobile_precache_appointments) }

      it 'does nothing' do
        subject.perform(user.uuid)
        expect(Mobile::V0::Appointment.get_cached(user)).to be_nil
      end
    end

    context 'with mobile_appointment_use_VAOS_v2 flag on' do
      before do
        Flipper.enable(:mobile_appointment_use_VAOS_v2)
        Timecop.freeze(Time.zone.parse('2022-01-01T19:25:00Z'))
        allow_any_instance_of(IAMUser).to receive(:icn).and_return('1012846043V576341')
        mock_clinic = { service_name: 'Friendly Name Optometry' }
        allow_any_instance_of(Mobile::V2::Appointments::Proxy).to receive(:get_clinic).and_return(mock_clinic)
      end

      it 'caches VAOS V2 appointments' do
        VCR.use_cassette('appointments/VAOS_v2/get_facility_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
            subject.perform(user.uuid)
          end
        end

        expect(Mobile::V0::Appointment.get_cached(user).collect(&:id)).to eq(['121133'])
      end
    end

    context 'with any errors' do
      it 'does not cache the appointments' do
        VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments_500', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments_default', match_requests_on: %i[method uri]) do
              expect(Mobile::V0::Appointment.get_cached(user)).to be_nil
              expect { subject.perform(user.uuid) }.to raise_error(Common::Exceptions::BackendServiceException)
              expect(Mobile::V0::Appointment.get_cached(user)).to be_nil
            end
          end
        end
      end
    end
  end
end
