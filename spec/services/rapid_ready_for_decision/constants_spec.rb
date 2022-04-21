# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RapidReadyForDecision::Constants do
  let(:form526_submission) { create(:form526_submission, :hypertension_claim_for_increase) }

  describe 'sidekiq_job and backup_sidekiq_job' do
    subject { RapidReadyForDecision::Constants::DISABILITIES }

    it 'all structs should have values for required keys' do
      expect(subject.values.pluck(:code).any?(nil)).to eq false
      expect(subject.values.pluck(:label).any?(nil)).to eq false
      expect(subject.values.pluck(:sidekiq_job).any?(nil)).to eq false
      expect(subject.values.pluck(:processor_class).any?(nil)).to eq false
    end

    it 'resolves all sidekiq_job values to classes' do
      expect { subject.values.pluck(:sidekiq_job).map(&:constantize) }.not_to raise_error
    end

    it 'resolves all backup_sidekiq_job values to classes' do
      expect { subject.values.pluck(:backup_sidekiq_job).compact.map(&:constantize) }.not_to raise_error
    end

    it 'resolves all processor_class values to classes' do
      expect do
        subject.values.pluck(:processor_class).map(&:constantize)
      end.not_to raise_error
    end
  end

  describe '.extract_disability_symbol_list' do
    subject { described_class.extract_disability_symbol_list(form526_submission) }

    it 'returns list of matching DISABILITIES elements' do
      expect(subject).to eq [:hypertension]
    end

    context 'multiple RRD disabilities' do
      let(:form526_submission) { create(:form526_submission, :hypertension_and_asthma_claim_for_increase) }

      it 'returns list of DISABILITIES including hypertension and asthma' do
        expect(subject).to eq %i[hypertension asthma]
      end
    end

    context 'non-RRD disability' do
      let(:form526_submission) { create(:form526_submission, :hypertension_and_non_rrd_claim_for_increase) }

      it 'returns list of DISABILITIES with nil for non-RRD disability' do
        expect(subject).to eq [:hypertension, nil]
      end
    end
  end

  describe '#processor' do
    subject { described_class.processor(form526_submission) }

    it 'returns instance of the processor class' do
      expect(subject.class).to eq RapidReadyForDecision::HypertensionProcessor
    end

    context 'for claim with unsupported disability' do
      let(:form526_submission) { create(:form526_submission) }

      it 'raises NoRrdProcessorForClaim for unsupported claims' do
        expect { subject }
          .to raise_error RapidReadyForDecision::Constants::NoRrdProcessorForClaim
      end
    end
  end
end
