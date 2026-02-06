# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultiPartyFormSubmission, type: :model do
  let(:form_type) { '21-2680' }

  describe 'associations' do
    it { is_expected.to belong_to(:primary_in_progress_form).class_name('InProgressForm') }
    it { is_expected.to belong_to(:secondary_in_progress_form).class_name('InProgressForm').optional }
    it { is_expected.to belong_to(:saved_claim).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:form_type) }
    it { is_expected.to validate_presence_of(:primary_user_uuid) }

    it 'validates secondary_email format' do
      expect(build(:multi_party_form_submission, secondary_email: '')).to be_valid
      expect(build(:multi_party_form_submission, secondary_email: 'test@example.com')).to be_valid
      expect(build(:multi_party_form_submission, secondary_email: 'not-an-email')).not_to be_valid
    end
  end

  describe 'scopes' do
    let(:uuid) { SecureRandom.uuid }
    let(:email) { 'test@example.com' }

    let!(:submission_for_primary_user) { create(:multi_party_form_submission, primary_user_uuid: uuid) }
    let!(:submission_for_secondary_user) { create(:multi_party_form_submission, secondary_user_uuid: uuid) }
    let!(:pending_submission) do
      create(:multi_party_form_submission,
             secondary_email: email,
             status: 'awaiting_secondary_start')
    end
    let!(:submitted_submission) do
      create(:multi_party_form_submission,
             secondary_email: email,
             status: 'submitted')
    end

    it '.for_primary_user returns correct submissions' do
      expect(described_class.for_primary_user(uuid)).to include(submission_for_primary_user)
      expect(described_class.for_primary_user(uuid)).not_to include(submission_for_secondary_user)
    end

    it '.for_secondary_user returns correct submissions' do
      expect(described_class.for_secondary_user(uuid)).to include(submission_for_secondary_user)
      expect(described_class.for_secondary_user(uuid)).not_to include(submission_for_primary_user)
    end

    it '.pending_for_secondary returns only pending submissions' do
      secondary_in_progress = create(
        :multi_party_form_submission,
        secondary_email: email,
        status: 'secondary_in_progress'
      )

      results = described_class.pending_for_secondary(email)

      expect(results).to include(pending_submission, secondary_in_progress)
      expect(results).not_to include(submitted_submission)
    end
  end

  describe 'aasm state machine' do
    let(:submission) { create(:multi_party_form_submission, :with_secondary) }

    it 'initializes in primary_in_progress' do
      expect(submission.status).to eq('primary_in_progress')
    end

    # TODO: uncomment this once NotifySecondaryPartyJob is implemented
    # it 'transitions from primary_in_progress to awaiting_secondary_start' do
    #     # expect(MultiPartyForms::NotifySecondaryPartyJob).to receive(:perform_async).with(submission.id)
    #     submission.primary_complete!
    #     expect(submission.status).to eq('awaiting_secondary_start')
    #     expect(submission.secondary_notified_at).to be_present
    # end

    it 'transitions from awaiting_secondary_start to secondary_in_progress' do
      submission.update!(status: 'awaiting_secondary_start')

      submission.secondary_start!

      expect(submission.status).to eq('secondary_in_progress')
    end

    # TODO: uncomment this once NotifyPrimaryPartyJob is implemented
    # it 'transitions from secondary_in_progress to awaiting_primary_review' do
    #     submission.update!(status: 'secondary_in_progress')
    #     # expect(MultiPartyForms::NotifyPrimaryPartyJob).to receive(:perform_async)
    #     #   .with(submission.id, 'secondary_completed')

    #     submission.secondary_complete!

    #     expect(submission.status).to eq('awaiting_primary_review')
    # end

    # TODO: uncomment this once SubmitFormJob is implemented
    # it 'transitions from awaiting_primary_review to submitted' do
    #     submission.update!(status: 'awaiting_primary_review')
    #     # expect(MultiPartyForms::SubmitFormJob).to receive(:perform_async).with(submission.id)

    #     submission.primary_submit!

    #     expect(submission).to be_submitted
    #     expect(submission.submitted_at).to be_present
    # end

    it 'guards primary_complete! transition if secondary_email is missing' do
      submission.update!(secondary_email: nil)
      expect { submission.primary_complete! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe 'form id generation' do
    let(:submission) { build(:multi_party_form_submission, form_type:) }

    it 'returns correctly formatted form IDs' do
      expect(submission.primary_form_id).to eq('21-2680-PRIMARY')
      expect(submission.secondary_form_id).to eq('21-2680-SECONDARY')
    end
  end

  describe 'secondary access token security' do
    let(:submission) { create(:multi_party_form_submission) }

    it 'generates and verifies a valid token' do
      raw_token = submission.generate_secondary_access_token!
      expect(submission.verify_secondary_token(raw_token)).to be true
    end

    it 'rejects an incorrect token' do
      submission.generate_secondary_access_token!
      expect(submission.verify_secondary_token('invalid-token-string')).to be false
    end

    it 'rejects an expired token' do
      raw_token = submission.generate_secondary_access_token!
      submission.update!(secondary_access_token_expires_at: 1.minute.ago)
      expect(submission.verify_secondary_token(raw_token)).to be false
    end
  end
end
