# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

describe Mobile::V0::AppointmentsService do
  let(:user) { FactoryBot.build(:iam_user) }
  let(:service) { Mobile::V0::AppointmentsService.new(user) }

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
    context 'when both va and cc appointments return 200s' do
      let(:start_date) { Time.now.utc }
      let(:end_date) { start_date + 3.months }
      let(:responses) do
        VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vaos/appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
            service.get_appointments(start_date, end_date, false)
          end
        end
      end

      it 'returns a 200 for the VA response' do
        expect(responses[:va].status).to eq(200)
      end

      it 'returns a 200 for the CC response' do
        expect(responses[:cc].status).to eq(200)
      end
    end
  end
end
