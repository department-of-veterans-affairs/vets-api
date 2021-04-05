# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe Mobile::V0::PreCacheAppointmentsJob, type: :job do
  before do
    iam_sign_in
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
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
                        healthcare_service: 'RR',
                        location: { name: 'RR',
                                    address: { street: 'clarksburg', city: 'md', state: 'MD',
                                               zip_code: '22222' },
                                    lat: nil,
                                    long: nil,
                                    phone: { area_code: '301', number: '916-1234', extension: nil },
                                    url: nil,
                                    code: nil },
                        minutes_duration: 60,
                        start_date_local: '2020-06-26T22:19:00.000-04:00',
                        start_date_utc: '2020-06-27T02:19:00.000Z',
                        status: 'BOOKED',
                        time_zone: 'America/New_York',
                        vetext_id: nil })
            end
          end
        end
      end

      context 'with any errors' do
        it 'does not cache the appointments' do
          VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cc_appointments_500', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_appointments_default', match_requests_on: %i[method uri]) do
                expect(Mobile::V0::Appointment.get_cached(user)).to be_nil
                subject.perform(user.uuid)
                expect(Mobile::V0::Appointment.get_cached(user)).to be_nil
              end
            end
          end
        end
      end
    end
  end
end
