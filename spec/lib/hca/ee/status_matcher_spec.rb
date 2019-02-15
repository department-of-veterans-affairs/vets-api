# frozen_string_literal: true

require 'rails_helper'

describe HCA::EE::StatusMatcher do
  describe '#parse' do
    subject do
      described_class.parse(enrollment_status, ineligibility_reason)
    end
    let(:ineligibility_reason) { nil }

    context 'when enrollment status is verified' do
      let(:enrollment_status) { 'Verified' }

      it 'should return enrolled' do
        expect(subject).to eq(:enrolled)
      end
    end

    context 'when enrollment_status is not eligible' do
      let(:enrollment_status) { 'Not Eligible' }

      context 'when text includes 24 months' do
        let(:ineligibility_reason) { '24 months foo' }

        it 'should return not enough time' do
          expect(subject).to eq(:inelig_not_enough_time)
        end
      end
    end
  end
end
