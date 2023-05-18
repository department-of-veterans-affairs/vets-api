# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe Mobile::V0::PreCacheAppointmentsJob, type: :job do
  let(:user) { create(:user, :loa3, icn: '1012846043V576341') }

  before do
    Sidekiq::Worker.clear_all
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }
  after { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::NullStore.new) }

  describe '.perform_async' do
    before { Timecop.freeze(Time.zone.parse('2022-01-01T19:25:00Z')) }

    after { Timecop.return }

    it 'caches the user\'s appointments' do
      VCR.use_cassette('appointments/VAOS_v2/get_facility_200', match_requests_on: %i[method uri]) do
        VCR.use_cassette('appointments/VAOS_v2/get_clinic_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
            expect(Mobile::V0::Appointment.get_cached(user)).to be_nil

            subject.perform(user.uuid)

            expect(Mobile::V0::Appointment.get_cached(user)).not_to be_nil
          end
        end
      end
    end

    it 'doesn\'t caches the user\'s appointments when failures are encountered' do
      VCR.use_cassette('appointments/VAOS_v2/get_facility_200', match_requests_on: %i[method uri]) do
        VCR.use_cassette('appointments/VAOS_v2/get_clinic_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/VAOS_v2/get_appointment_200_partial_error',
                           match_requests_on: %i[method uri]) do
            expect(Mobile::V0::Appointment.get_cached(user)).to be_nil

            subject.perform(user.uuid)

            expect(Mobile::V0::Appointment.get_cached(user)).to be_nil
          end
        end
      end
    end

    context 'with mobile_precache_appointments flag off' do
      before { Flipper.disable(:mobile_precache_appointments) }

      after { Flipper.enable(:mobile_precache_appointments) }

      it 'does nothing' do
        expect do
          subject.perform(user.uuid)
        end.not_to raise_error
        expect(Mobile::V0::Appointment.get_cached(user)).to be_nil
      end
    end

    context 'with IAM user' do
      let(:user) { FactoryBot.build(:iam_user) }

      before do
        allow_any_instance_of(IAMUser).to receive(:icn).and_return('1012846043V576341')
        iam_sign_in(user)
      end

      it 'caches the user\'s appointments' do
        VCR.use_cassette('appointments/VAOS_v2/get_facility_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/VAOS_v2/get_clinic_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
              expect(Mobile::V0::Appointment.get_cached(user)).to be_nil

              subject.perform(user.uuid)

              expect(Mobile::V0::Appointment.get_cached(user)).not_to be_nil
            end
          end
        end
      end
    end

    context 'when user is not found' do
      it 'caches the expected claims and appeals' do
        expect do
          subject.perform('iamtheuuidnow')
        end.to raise_error(described_class::MissingUserError, 'iamtheuuidnow')
        expect(Mobile::V0::Appointment.get_cached(user)).to be_nil
      end
    end
  end
end
