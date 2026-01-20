# frozen_string_literal: true

require 'rails_helper'
require 'support/models/shared_examples/submission'

RSpec.describe BGS::Submission, type: :model do
  # Use shared examples but skip the problematic latest_attempt test that doesn't work with foreign keys
  it { is_expected.to validate_presence_of :form_id }

  describe 'encrypted attributes' do
    it 'responds to encrypted fields' do
      subject = described_class.new
      expect(subject).to respond_to(:reference_data)
    end
  end

  # Override the shared example that doesn't work with BGS foreign key constraints
  describe '#latest_attempt (shared example override)' do
    it 'returns the last attempt' do
      submission = create(:bgs_submission)
      expect(submission.latest_attempt).to be_nil

      attempts = []
      5.times { attempts << create(:bgs_submission_attempt, submission:) }

      expect(submission.submission_attempts.length).to eq 5
      expect(submission.latest_attempt).to eq attempts.last
    end
  end

  describe 'database configuration' do
    it 'uses the correct table name' do
      expect(described_class.table_name).to eq('bgs_submissions')
    end
  end

  describe 'includes' do
    it 'includes SubmissionEncryption' do
      expect(described_class.included_modules).to include(SubmissionEncryption)
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:submission_attempts).class_name('BGS::SubmissionAttempt') }
    it { is_expected.to have_many(:submission_attempts).dependent(:destroy) }
    it { is_expected.to have_many(:submission_attempts).with_foreign_key(:bgs_submission_id) }
    it { is_expected.to have_many(:submission_attempts).inverse_of(:submission) }
    it { is_expected.to belong_to(:saved_claim).optional }
  end

  describe 'inheritance' do
    it 'inherits from Submission' do
      expect(described_class.superclass).to eq(Submission)
    end
  end

  describe '#latest_attempt' do
    let(:submission) { create(:bgs_submission) }

    context 'when no attempts exist' do
      it 'returns nil' do
        expect(submission.latest_attempt).to be_nil
      end
    end

    context 'when multiple attempts exist' do
      let!(:first_attempt) { create(:bgs_submission_attempt, submission:, created_at: 2.hours.ago) }
      let!(:second_attempt) { create(:bgs_submission_attempt, submission:, created_at: 1.hour.ago) }
      let!(:latest_attempt) { create(:bgs_submission_attempt, submission:, created_at: 30.minutes.ago) }

      it 'returns the most recently created attempt' do
        expect(submission.latest_attempt).to eq(latest_attempt)
      end

      it 'orders by created_at descending and takes the first' do
        attempts = submission.submission_attempts.order(created_at: :desc)
        expect(attempts.to_a).to eq([latest_attempt, second_attempt, first_attempt])
        expect(submission.latest_attempt).to eq(attempts.first)
      end
    end
  end

  describe '#latest_pending_attempt' do
    let(:submission) { create(:bgs_submission) }

    context 'when no pending attempts exist' do
      before do
        create(:bgs_submission_attempt, submission:, status: 'submitted')
        create(:bgs_submission_attempt, submission:, status: 'failure')
      end

      it 'returns nil' do
        expect(submission.latest_pending_attempt).to be_nil
      end
    end

    context 'when multiple pending attempts exist' do
      let!(:first_pending) do
        create(:bgs_submission_attempt, submission:, status: 'pending', created_at: 2.hours.ago)
      end
      let!(:submitted_attempt) do
        create(:bgs_submission_attempt, submission:, status: 'submitted', created_at: 1.hour.ago)
      end
      let!(:latest_pending) do
        create(:bgs_submission_attempt, submission:, status: 'pending', created_at: 30.minutes.ago)
      end

      it 'returns the most recently created pending attempt' do
        expect(submission.latest_pending_attempt).to eq(latest_pending)
      end

      it 'ignores non-pending attempts' do
        pending_attempts = submission.submission_attempts.where(status: 'pending')
        expect(pending_attempts.count).to eq(2)
        expect(submission.latest_pending_attempt).to eq(latest_pending)
      end
    end

    context 'when only one pending attempt exists' do
      let!(:pending_attempt) { create(:bgs_submission_attempt, submission:, status: 'pending') }

      it 'returns that pending attempt' do
        expect(submission.latest_pending_attempt).to eq(pending_attempt)
      end
    end
  end

  describe '#non_failure_attempt' do
    let(:submission) { create(:bgs_submission) }

    context 'when no non-failure attempts exist' do
      before do
        create(:bgs_submission_attempt, submission:, status: 'failure')
        create(:bgs_submission_attempt, submission:, status: 'failure')
      end

      it 'returns nil' do
        expect(submission.non_failure_attempt).to be_nil
      end
    end

    context 'when multiple non-failure attempts exist' do
      let!(:failure_attempt) do
        create(:bgs_submission_attempt, submission:, status: 'failure', created_at: 3.hours.ago)
      end
      let!(:pending_attempt) do
        create(:bgs_submission_attempt, submission:, status: 'pending', created_at: 2.hours.ago)
      end
      let!(:submitted_attempt) do
        create(:bgs_submission_attempt, submission:, status: 'submitted', created_at: 1.hour.ago)
      end

      it 'returns the first non-failure attempt (pending or submitted)' do
        expect(submission.non_failure_attempt).to eq(pending_attempt)
      end

      it 'excludes failure attempts' do
        non_failure_attempts = submission.submission_attempts.where(status: %w[pending submitted])
        expect(non_failure_attempts.count).to eq(2)
        expect(submission.non_failure_attempt).to eq(non_failure_attempts.first)
      end
    end

    context 'when only pending attempts exist' do
      let!(:pending_attempt) { create(:bgs_submission_attempt, submission:, status: 'pending') }

      it 'returns the pending attempt' do
        expect(submission.non_failure_attempt).to eq(pending_attempt)
      end
    end

    context 'when only submitted attempts exist' do
      let!(:submitted_attempt) { create(:bgs_submission_attempt, submission:, status: 'submitted') }

      it 'returns the submitted attempt' do
        expect(submission.non_failure_attempt).to eq(submitted_attempt)
      end
    end
  end

  describe 'encrypted attributes functionality' do
    let(:submission) { build(:bgs_submission) }

    it 'responds to reference_data' do
      expect(submission).to respond_to(:reference_data)
    end

    it 'can set and retrieve reference_data' do
      reference_data = { 'icn' => '1234567890V123456', 'ssn' => '123456789' }
      submission.reference_data = reference_data
      expect(submission.reference_data).to eq(reference_data)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:form_id) }
  end

  describe 'factory' do
    it 'can create a valid submission' do
      submission = build(:bgs_submission)
      expect(submission).to be_valid
    end

    it 'creates submission with correct attributes' do
      submission = create(:bgs_submission, form_id: '21-686C')
      expect(submission.form_id).to eq('21-686C')
      expect(submission.latest_status).to be_present
      expect(submission.saved_claim).to be_present
    end
  end
end
