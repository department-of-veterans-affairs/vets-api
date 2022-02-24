# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RapidReadyForDecision::ProcessorSelector do
  subject { described_class.new(submission) }

  let(:submission) { create(:form526_submission) }

  describe '#processor_class' do
    context 'when given non-RRD-applicable claim submission' do
      it 'returns nil' do
        expect(subject.rrd_applicable?).to eq false
        expect(subject.processor_class).to eq nil
      end
    end

    context 'when given single-issue hypertension claim for increase submission' do
      let(:submission) { create(:form526_submission, :hypertension_claim_for_increase) }

      it 'returns DisabilityCompensationJob' do
        expect(subject.rrd_applicable?).to eq true
        expect(subject.processor_class).to eq RapidReadyForDecision::DisabilityCompensationJob
      end
    end
  end
end
