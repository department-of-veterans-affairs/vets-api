# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RapidReadyForDecision::SidekiqJobSelector do
  subject { described_class.new(submission) }

  let(:submission) { build(:form526_submission) }

  describe '#sidekiq_job' do
    context 'when given non-RRD-applicable claim submission' do
      it 'returns nil' do
        expect(subject.rrd_applicable?).to eq false
        expect(subject.sidekiq_job).to eq nil
      end
    end

    context 'when given single-issue hypertension claim for increase submission' do
      let(:submission) { build(:form526_submission, :hypertension_claim_for_increase) }

      it 'returns RRD processor' do
        expect(subject.rrd_applicable?).to eq true
        expect(subject.sidekiq_job).to eq RapidReadyForDecision::Form526BaseJob
        expect(subject.sidekiq_job(backup: true)).to eq RapidReadyForDecision::DisabilityCompensationJob
      end
    end

    context 'when given single-issue asthma claim for increase submission' do
      let(:submission) { build(:form526_submission, :asthma_claim_for_increase) }

      it 'returns Form526AsthmaJob' do
        expect(subject.rrd_applicable?).to eq true
        expect(subject.sidekiq_job).to eq RapidReadyForDecision::Form526AsthmaJob
      end
    end
  end
end
