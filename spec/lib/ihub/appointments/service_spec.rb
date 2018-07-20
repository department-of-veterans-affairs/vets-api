# frozen_string_literal: true

require 'rails_helper'

describe IHub::Appointments::Service do
  let(:user) { build(:user, :loa3) }

  subject { described_class.new(user) }

  describe '#appointments' do
    context 'when successful' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return('1234')
      end

      it 'returns a status of 200' do
        VCR.use_cassette('ihub/appointments/success', VCR::MATCH_EVERYTHING) do
          response = subject.appointments

          expect(response).to be_ok
        end
      end

      it 'returns an array of appointment data' do
        VCR.use_cassette('ihub/appointments/real_success', VCR::MATCH_EVERYTHING) do
          response    = subject.appointments
          appointment = response.response_data&.dig('data')&.first
          facility    = appointment&.dig('facility_name')

          expect(facility).to be_present
        end
      end
    end

    context 'when user does not have an ICN' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return(nil)
      end

      it 'raises an error' do
        expect { subject.appointments }.to raise_error(StandardError, 'User has no ICN')
      end
    end
  end
end
