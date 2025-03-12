# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Create10203ApplicantDecisionLetters, form: :education_benefits, type: :model do
  subject { described_class.new }

  let(:time) { Time.zone.now }
  let(:count) do
    EducationBenefitsClaim.includes(:saved_claim, :education_stem_automated_decision).where(
      processed_at: (time - 24.hours)..time,
      saved_claims: {
        form_id: '22-10203'
      },
      education_stem_automated_decisions: {
        automated_decision_state: EducationStemAutomatedDecision::DENIED
      }
    ).count
  end

  describe '#perform' do
    EducationBenefitsClaim.delete_all
    EducationStemAutomatedDecision.delete_all

    before do
      subject.instance_variable_set(:@time, time)
    end

    context 'with denied records' do
      let!(:education_benefits_claim) do
        create(:education_benefits_claim_10203,
               processed_at: time.beginning_of_day,
               education_stem_automated_decision: build(:education_stem_automated_decision, :with_poa, :denied))
      end

      it 'logs number of applications being processed' do
        expect(subject).to receive('log_info')
          .with("Processing #{count} denied application(s)")
          .once
        expect(subject.perform).to be(true)
      end
    end

    context 'with no records' do
      before do
        EducationBenefitsClaim.delete_all
        EducationStemAutomatedDecision.delete_all
      end

      it 'prints a statement and exits' do
        expect(StemApplicantDenialMailer).not_to receive(:build)
        expect(subject).to receive('log_info').with('No records to process.').once
        expect(subject.perform).to be(true)
      end
    end

    context 'with error' do
      before do
        EducationBenefitsClaim.delete_all
        EducationStemAutomatedDecision.delete_all
      end

      it 'prints a statement and exits' do
        create(:education_benefits_claim_10203,
               processed_at: time.beginning_of_day,
               education_stem_automated_decision:
                   build(:education_stem_automated_decision, :with_poa, :denied))

        expect(StemApplicantDenialMailer).to receive(:build).and_raise(StandardError.new)
        expect(subject).to receive('log_exception_to_sentry').with(any_args).once
        expect(subject.perform).to be(true)
      end
    end
  end
end
