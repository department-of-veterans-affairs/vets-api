# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/sidekiq/bgs/bgs_form_job'
require 'bgsv2/service'

RSpec.describe DependentsBenefits::Sidekiq::BGS::BGSFormJob, type: :job do
  # Create a concrete test class since BGSFormJob is abstract
  let(:test_job_class) do
    Class.new(described_class) do
      def submit_form(_claim_data)
        # No-op for testing
      end

      def form_id
        '21-686C'
      end
    end
  end

  let(:user) { create(:evss_user) }
  let(:parent_claim) { create(:dependents_claim) }
  let(:saved_claim) { create(:add_remove_dependents_claim) }
  let(:user_data) { { 'veteran_information' => { 'full_name' => { 'first' => 'John', 'last' => 'Doe' } } }.to_json }
  let!(:parent_group) { create(:parent_claim_group, parent_claim:, user_data:) }
  let!(:current_group) { create(:saved_claim_group, saved_claim:, parent_claim:) }
  let(:job) { test_job_class.new }

  before do
    # Initialize job with current claim context
    job.instance_variable_set(:@claim_id, parent_claim.id)
  end

  describe '#find_or_create_form_submission' do
    it 'creates a new BGS::Submission if one does not exist' do
      expect do
        job.send(:find_or_create_form_submission, saved_claim)
      end.to change(BGS::Submission, :count).by(1)
    end

    it 'returns existing BGS::Submission if one already exists' do
      existing_submission = create(:bgs_submission, saved_claim:, form_id: '21-686C')

      result = job.send(:find_or_create_form_submission, saved_claim)

      expect(result).to eq(existing_submission)
      expect(BGS::Submission.count).to eq(1)
    end
  end

  describe '#create_form_submission_attempt' do
    let(:submission) { create(:bgs_submission, saved_claim:, form_id: '21-686C') }

    it 'creates a new BGS::SubmissionAttempt' do
      expect do
        job.send(:create_form_submission_attempt, submission)
      end.to change(BGS::SubmissionAttempt, :count).by(1)
    end

    it 'associates the attempt with the submission' do
      attempt = job.send(:create_form_submission_attempt, submission)

      expect(attempt.submission).to eq(submission)
    end
  end

  describe '#submission_previously_succeeded?' do
    let(:submission) { create(:bgs_submission, saved_claim:, form_id: '21-686C') }

    context 'when submission has a non-failure attempt' do
      before do
        create(:bgs_submission_attempt, submission:, status: 'submitted')
      end

      it 'returns true' do
        expect(job.send(:submission_previously_succeeded?, submission)).to be true
      end
    end

    context 'when submission has only failure attempts' do
      before do
        create(:bgs_submission_attempt, submission:, status: 'failure')
      end

      it 'returns false' do
        expect(job.send(:submission_previously_succeeded?, submission)).to be false
      end
    end

    context 'when submission is nil' do
      it 'returns false' do
        expect(job.send(:submission_previously_succeeded?, nil)).to be false
      end
    end
  end

  describe '#mark_submission_attempt_succeeded' do
    let(:submission) { create(:bgs_submission, saved_claim:, form_id: '21-686C') }
    let(:submission_attempt) { create(:bgs_submission_attempt, submission:, status: 'pending') }

    it 'marks the submission attempt as submitted' do
      expect { job.send(:mark_submission_attempt_succeeded, submission_attempt) }
        .to change { submission_attempt.reload.status }.from('pending').to('submitted')
    end

    it 'handles nil submission_attempt gracefully' do
      expect { job.send(:mark_submission_attempt_succeeded, nil) }.not_to raise_error
    end
  end

  describe '#mark_submission_attempt_failed' do
    let(:submission) { create(:bgs_submission, saved_claim:, form_id: '21-686C') }
    let(:submission_attempt) { create(:bgs_submission_attempt, submission:, status: 'pending') }
    let(:error) { StandardError.new('Test error') }

    it 'marks the submission attempt as failure' do
      expect { job.send(:mark_submission_attempt_failed, submission_attempt, error) }
        .to change { submission_attempt.reload.status }.from('pending').to('failure')
    end

    it 'records the error message' do
      job.send(:mark_submission_attempt_failed, submission_attempt, error)
      submission_attempt.reload

      expect(submission_attempt.error_message).to eq('Test error')
    end

    it 'handles nil submission_attempt gracefully' do
      expect { job.send(:mark_submission_attempt_failed, nil, error) }.not_to raise_error
    end
  end

  describe '#permanent_failure?' do
    before do
      stub_const('BGS::Job::FILTERED_ERRORS', %w[INVALID_SSN DUPLICATE_CLAIM])
    end

    context 'when error is nil' do
      it 'returns false' do
        expect(job.send(:permanent_failure?, nil)).to be false
      end
    end

    context 'when error message contains filtered error' do
      it 'returns true for INVALID_SSN' do
        error = StandardError.new('INVALID_SSN: Social Security Number is invalid')

        expect(job.send(:permanent_failure?, error)).to be true
      end

      it 'returns true for DUPLICATE_CLAIM' do
        error = StandardError.new('DUPLICATE_CLAIM: This claim already exists')

        expect(job.send(:permanent_failure?, error)).to be true
      end
    end

    context 'when error cause contains filtered error' do
      it 'returns true when cause message matches' do
        cause = StandardError.new('INVALID_SSN: Social Security Number is invalid')
        error = StandardError.new('Wrapped error')
        allow(error).to receive(:cause).and_return(cause)

        expect(job.send(:permanent_failure?, error)).to be true
      end
    end

    context 'when error does not contain filtered error' do
      it 'returns false' do
        error = StandardError.new('Temporary network error')

        expect(job.send(:permanent_failure?, error)).to be false
      end
    end
  end
end
