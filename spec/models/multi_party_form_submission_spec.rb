# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultiPartyFormSubmission, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:form_type) }
    it { is_expected.to validate_presence_of(:primary_user_uuid) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:primary_in_progress_form).optional }
    it { is_expected.to belong_to(:secondary_in_progress_form).optional }
    it { is_expected.to belong_to(:saved_claim).optional }
  end

  describe 'state machine' do
    let(:submission) { create(:multi_party_form_submission) }

    it 'has initial state of primary_in_progress' do
      expect(submission.status).to eq('primary_in_progress')
    end

    describe 'primary_complete event' do
      it 'transitions from primary_in_progress to awaiting_secondary_completion' do
        expect(submission.status).to eq('primary_in_progress')

        submission.primary_complete!

        expect(submission.status).to eq('awaiting_secondary_completion')
      end

      it 'updates secondary_notified_at timestamp' do
        expect(submission.secondary_notified_at).to be_nil

        submission.primary_complete!

        submission.reload
        expect(submission.secondary_notified_at).not_to be_nil
      end

      it 'cannot transition from awaiting_secondary_completion' do
        submission.update!(status: 'awaiting_secondary_completion')

        expect { submission.primary_complete! }.to raise_error(AASM::InvalidTransition)
      end

      it 'cannot transition from awaiting_primary_review' do
        submission.update!(status: 'awaiting_primary_review')

        expect { submission.primary_complete! }.to raise_error(AASM::InvalidTransition)
      end

      it 'cannot transition from submitted' do
        submission.update!(status: 'submitted')

        expect { submission.primary_complete! }.to raise_error(AASM::InvalidTransition)
      end
    end

    describe 'secondary_complete event' do
      let(:submission) { create(:multi_party_form_submission, :with_primary_completed) }

      it 'transitions from awaiting_secondary_completion to awaiting_primary_review' do
        expect(submission.status).to eq('awaiting_secondary_completion')

        submission.secondary_complete!

        expect(submission.status).to eq('awaiting_primary_review')
      end

      it 'cannot transition from primary_in_progress' do
        submission.update!(status: 'primary_in_progress')

        expect { submission.secondary_complete! }.to raise_error(AASM::InvalidTransition)
      end
    end

    describe 'primary_submit event' do
      let(:submission) { create(:multi_party_form_submission, :with_secondary_completed) }

      it 'transitions from awaiting_primary_review to submitted' do
        expect(submission.status).to eq('awaiting_primary_review')

        submission.primary_submit!

        expect(submission.status).to eq('submitted')
      end

      it 'updates submitted_at timestamp' do
        expect(submission.submitted_at).to be_nil

        submission.primary_submit!

        submission.reload
        expect(submission.submitted_at).not_to be_nil
      end

      it 'cannot transition from primary_in_progress' do
        submission.update!(status: 'primary_in_progress')

        expect { submission.primary_submit! }.to raise_error(AASM::InvalidTransition)
      end

      it 'cannot transition from awaiting_secondary_completion' do
        submission.update!(status: 'awaiting_secondary_completion')

        expect { submission.primary_submit! }.to raise_error(AASM::InvalidTransition)
      end
    end

    describe 'may_primary_complete?' do
      it 'returns true when in primary_in_progress state' do
        submission.update!(status: 'primary_in_progress')
        expect(submission.may_primary_complete?).to be true
      end

      it 'returns false when in awaiting_secondary_completion state' do
        submission.update!(status: 'awaiting_secondary_completion')
        expect(submission.may_primary_complete?).to be false
      end

      it 'returns false when in awaiting_primary_review state' do
        submission.update!(status: 'awaiting_primary_review')
        expect(submission.may_primary_complete?).to be false
      end

      it 'returns false when in submitted state' do
        submission.update!(status: 'submitted')
        expect(submission.may_primary_complete?).to be false
      end
    end
  end
end
