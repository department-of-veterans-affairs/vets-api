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
              expect(Mobile::V0::Appointment.get_cached_appointments(user)).to be_nil
              subject.perform(user.uuid)
              first_appointment = JSON.parse(Mobile::V0::Appointment.get_cached_appointments(user))['data'].first
              expect(
                first_appointment
              ).to eq({
                        'id' => '202006031600983000030800000000000000',
                        'type' => 'appointment',
                        'attributes' => {
                          'appointment_type' => 'VA',
                          'cancel_id' => 'MjAyMDExMDMwOTAwMDA=-MzA4-NDQy-Q0hZIFBDIEtJTFBBVFJJQ0s=',
                          'comment' => nil,
                          'healthcare_service' => 'CHY PC KILPATRICK',
                          'location' => {
                            'name' => 'CHEYENNE VAMC',
                            'address' => {
                              'street' => '2360 East Pershing Boulevard',
                              'city' => 'Cheyenne',
                              'state' => 'WY',
                              'zip_code' => '82001-5356'
                            },
                            'lat' => 41.148027,
                            'long' => -104.7862575,
                            'phone' => {
                              'area_code' => '307',
                              'number' => '778-7550',
                              'extension' => nil
                            },
                            'url' => nil,
                            'code' => nil
                          },
                          'minutes_duration' => 20,
                          'start_date_local' => '2020-11-03T09:00:00.000-07:00',
                          'start_date_utc' => '2020-11-03T16:00:00.000+00:00',
                          'status' => 'BOOKED',
                          'time_zone' => 'America/Denver'
                        }
                      })
            end
          end
        end
      end

      context 'with any errors' do
        it 'does not cache the appointments' do
          VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cc_appointments_500', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_appointments_default', match_requests_on: %i[method uri]) do
                expect(Mobile::V0::Appointment.get_cached_appointments(user)).to be_nil
                subject.perform(user.uuid)
                expect(Mobile::V0::Appointment.get_cached_appointments(user)).to be_nil
              end
            end
          end
        end
      end
    end
  end
end
