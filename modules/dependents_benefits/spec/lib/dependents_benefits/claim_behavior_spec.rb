# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/claim_behavior'

RSpec.describe DependentsBenefits::ClaimBehavior do
  before do
    allow(PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
  end

  let(:claim) { create(:dependents_claim) }

  describe '#submissions_succeeded?' do
    context 'when BGS::Submission has an attempt with status == "submitted"' do
      it 'returns true' do
        submission = create(:bgs_submission, saved_claim_id: claim.id)
        create(:bgs_submission_attempt, submission:, status: 'submitted')

        expect(claim.submissions_succeeded?).to be true
      end
    end

    context 'when BGS::Submission has an attempt with status == "pending"' do
      it 'returns false' do
        submission = create(:bgs_submission, saved_claim_id: claim.id)
        create(:bgs_submission_attempt, submission:, status: 'pending')

        expect(claim.submissions_succeeded?).to be false
      end
    end

    context 'when BGS::Submission has no attempts' do
      it 'returns false' do
        create(:bgs_submission, saved_claim_id: claim.id)

        expect(claim.submissions_succeeded?).to be false
      end
    end

    context 'when there are no submissions for the claim' do
      it 'returns false' do
        expect(claim.submissions_succeeded?).to be false
      end
    end

    context 'when there are multiple submissions with mixed statuses' do
      it 'returns false if any submission has non-submitted attempts' do
        submission1 = create(:bgs_submission, saved_claim_id: claim.id)
        submission2 = create(:bgs_submission, saved_claim_id: claim.id)

        create(:bgs_submission_attempt, submission: submission1, status: 'submitted')
        create(:bgs_submission_attempt, submission: submission2, status: 'pending')

        expect(claim.submissions_succeeded?).to be false
      end

      it 'returns true if all submissions have submitted attempts' do
        submission1 = create(:bgs_submission, saved_claim_id: claim.id)
        submission2 = create(:bgs_submission, saved_claim_id: claim.id)

        create(:bgs_submission_attempt, submission: submission1, status: 'submitted')
        create(:bgs_submission_attempt, submission: submission2, status: 'submitted')

        expect(claim.submissions_succeeded?).to be true
      end
    end

    context 'when submission has multiple attempts' do
      it 'uses the latest attempt status' do
        submission = create(:bgs_submission, saved_claim_id: claim.id)

        # Create attempts in chronological order
        create(:bgs_submission_attempt, submission:, status: 'pending', created_at: 1.hour.ago)
        create(:bgs_submission_attempt, submission:, status: 'submitted', created_at: 30.minutes.ago)

        expect(claim.submissions_succeeded?).to be true
      end
    end
  end
end
