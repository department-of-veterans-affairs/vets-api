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

      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('ihub/appointments/success', VCR::MATCH_EVERYTHING) do
          response = subject.appointments

          expect(response).to be_ok
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
