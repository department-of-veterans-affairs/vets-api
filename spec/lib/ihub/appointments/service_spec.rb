

# frozen_string_literal: true

require 'rails_helper'

describe IHub::Appointments::Service do
  let(:user) { build(:user, :loa3) }

  subject { described_class.new(user) }

  before do
    allow_any_instance_of(User).to receive(:icn).and_return('1234')
  end

  describe '#appointments' do
    context 'when successful' do
      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('ihub/appointments/success', VCR::MATCH_EVERYTHING) do
          response = subject.appointments

          expect(response).to be_ok
        end
      end
    end
  end
end
