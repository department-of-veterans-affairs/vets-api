# frozen_string_literal: true

require 'rails_helper'
require 'support/models/shared_examples/submission_attempt'

RSpec.describe BGS::SubmissionAttempt, type: :model do
  let(:submission_attempt) { build(:bgs_submission_attempt) }

  it_behaves_like 'a SubmissionAttempt model'

  describe 'database configuration' do
    it 'uses the correct table name' do
      expect(described_class.table_name).to eq('bgs_submission_attempts')
    end
  end

  describe 'inheritance' do
    it 'inherits from SubmissionAttempt' do
      expect(described_class.superclass).to eq(SubmissionAttempt)
    end
  end

  describe 'includes' do
    it 'includes SubmissionAttemptEncryption' do
      expect(described_class.included_modules).to include(SubmissionAttemptEncryption)
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:submission).class_name('BGS::Submission') }
    it { is_expected.to belong_to(:submission).with_foreign_key(:bgs_submission_id) }
    it { is_expected.to belong_to(:submission).inverse_of(:submission_attempts) }
    it { is_expected.to have_one(:saved_claim).through(:submission) }
  end

  describe 'enums' do
    # BGS::SubmissionAttempt uses a database enum, not an integer-backed Rails enum
    it 'has status enum with correct values' do
      expect(described_class.statuses).to eq({
                                               'pending' => 'pending',
                                               'submitted' => 'submitted',
                                               'failure' => 'failure'
                                             })
    end

    it 'responds to status enum methods' do
      attempt = build(:bgs_submission_attempt)
      expect(attempt).to respond_to(:pending?)
      expect(attempt).to respond_to(:submitted?)
      expect(attempt).to respond_to(:failure?)
    end

    describe 'status values' do
      it 'has correct enum values' do
        expect(described_class.statuses).to eq({
                                                 'pending' => 'pending',
                                                 'submitted' => 'submitted',
                                                 'failure' => 'failure'
                                               })
      end
    end
  end

  describe 'constants' do
    it 'defines STATS_KEY' do
      expect(described_class::STATS_KEY).to eq('api.bgs.submission_attempt')
    end
  end

  describe '#fail!' do
    let(:submission_attempt) { create(:bgs_submission_attempt, status: 'pending') }
    let(:error) { StandardError.new('Test error message') }
    let(:monitor) { instance_double(Logging::Monitor) }

    before do
      allow(submission_attempt).to receive(:monitor).and_return(monitor)
      allow(monitor).to receive(:track_request)
    end

    it 'updates error_message with the error message' do
      submission_attempt.fail!(error:)
      expect(submission_attempt.error_message).to eq('Test error message')
    end

    it 'sets status to failure' do
      submission_attempt.fail!(error:)
      expect(submission_attempt.status).to eq('failure')
    end

    it 'handles nil error gracefully' do
      submission_attempt.fail!(error: nil)
      expect(submission_attempt.error_message).to be_nil
      expect(submission_attempt.status).to eq('failure')
    end

    it 'tracks the error with monitor' do
      expect(monitor).to receive(:track_request).with(
        :error,
        'BGS Submission Attempt failed',
        'api.bgs.submission_attempt',
        hash_including(
          submission_id: submission_attempt.submission.id,
          form_type: submission_attempt.submission.form_id,
          from_state: 'pending',
          to_state: 'failure',
          message: 'BGS Submission Attempt failed'
        )
      )
      submission_attempt.fail!(error:)
    end
  end

  describe '#pending!' do
    let(:submission_attempt) { create(:bgs_submission_attempt, status: 'submitted') }
    let(:monitor) { instance_double(Logging::Monitor) }

    before do
      allow(submission_attempt).to receive(:monitor).and_return(monitor)
      allow(monitor).to receive(:track_request)
    end

    it 'sets status to pending' do
      submission_attempt.pending!
      expect(submission_attempt.status).to eq('pending')
    end

    it 'tracks the status change with monitor' do
      expect(monitor).to receive(:track_request).with(
        :info,
        'BGS Submission Attempt is pending',
        'api.bgs.submission_attempt',
        hash_including(
          submission_id: submission_attempt.submission.id,
          form_type: submission_attempt.submission.form_id,
          from_state: 'submitted',
          to_state: 'pending',
          message: 'BGS Submission Attempt is pending'
        )
      )
      submission_attempt.pending!
    end
  end

  describe '#success!' do
    let(:submission_attempt) { create(:bgs_submission_attempt, status: 'pending') }
    let(:monitor) { instance_double(Logging::Monitor) }

    before do
      allow(submission_attempt).to receive(:monitor).and_return(monitor)
      allow(monitor).to receive(:track_request)
    end

    it 'sets status to submitted' do
      submission_attempt.success!
      expect(submission_attempt.status).to eq('submitted')
    end

    it 'tracks the status change with monitor' do
      expect(monitor).to receive(:track_request).with(
        :info,
        'BGS Submission Attempt is submitted',
        'api.bgs.submission_attempt',
        hash_including(
          submission_id: submission_attempt.submission.id,
          form_type: submission_attempt.submission.form_id,
          from_state: 'pending',
          to_state: 'submitted',
          message: 'BGS Submission Attempt is submitted'
        )
      )
      submission_attempt.success!
    end
  end

  describe '#monitor' do
    it 'returns a Logging::Monitor instance' do
      expect(submission_attempt.monitor).to be_a(Logging::Monitor)
    end

    it 'memoizes the monitor instance' do
      first_call = submission_attempt.monitor
      second_call = submission_attempt.monitor
      expect(first_call).to be(second_call)
    end

    it 'initializes monitor with correct name' do
      expect(Logging::Monitor).to receive(:new).with('bgs_submission_attempt').and_call_original
      submission_attempt.monitor
    end
  end

  describe '#status_change_hash' do
    let(:submission) { create(:bgs_submission, form_id: '21-686C') }
    let(:submission_attempt) { create(:bgs_submission_attempt, submission:, status: 'pending') }

    context 'when status changes' do
      before do
        submission_attempt.update(status: 'submitted')
      end

      it 'returns hash with correct structure' do
        hash = submission_attempt.status_change_hash
        expect(hash).to include(
          submission_id: submission.id,
          claim_id: submission.saved_claim_id,
          form_type: '21-686C',
          from_state: 'pending',
          to_state: 'submitted'
        )
      end
    end

    context 'when no status change has occurred' do
      it 'returns hash with nil from_state' do
        hash = submission_attempt.status_change_hash
        expect(hash).to include(
          submission_id: submission.id,
          claim_id: submission.saved_claim_id,
          form_type: '21-686C',
          from_state: nil,
          to_state: 'pending'
        )
      end
    end
  end

  describe 'encrypted attributes' do
    let(:submission_attempt) { build(:bgs_submission_attempt) }

    it 'responds to encrypted fields' do
      expect(submission_attempt).to respond_to(:metadata)
      expect(submission_attempt).to respond_to(:error_message)
      expect(submission_attempt).to respond_to(:response)
    end

    it 'can set and retrieve metadata' do
      metadata = { 'form_id' => '21-686C', 'submission_type' => 'bgs' }
      submission_attempt.metadata = metadata
      expect(submission_attempt.metadata).to eq(metadata)
    end

    it 'can set and retrieve error_message' do
      error_message = { 'error_class' => 'BGS::ServiceError', 'error_message' => 'Service unavailable' }
      submission_attempt.error_message = error_message
      expect(submission_attempt.error_message).to eq(error_message)
    end

    it 'can set and retrieve response' do
      response = { 'claim_id' => '12345678', 'success' => true }
      submission_attempt.response = response
      expect(submission_attempt.response).to eq(response)
    end
  end

  describe 'status transitions' do
    let(:submission_attempt) { create(:bgs_submission_attempt) }

    context 'from pending' do
      before { submission_attempt.update(status: 'pending') }

      it 'can transition to submitted' do
        expect { submission_attempt.success! }.to change(submission_attempt, :status).from('pending').to('submitted')
      end

      it 'can transition to failure' do
        expect { submission_attempt.fail!(error: StandardError.new('Error')) }
          .to change(submission_attempt, :status).from('pending').to('failure')
      end
    end

    context 'from submitted' do
      before { submission_attempt.update(status: 'submitted') }

      it 'can transition back to pending' do
        expect { submission_attempt.pending! }.to change(submission_attempt, :status).from('submitted').to('pending')
      end

      it 'can transition to failure' do
        expect { submission_attempt.fail!(error: StandardError.new('Error')) }
          .to change(submission_attempt, :status).from('submitted').to('failure')
      end
    end

    context 'from failure' do
      before { submission_attempt.update(status: 'failure') }

      it 'can transition back to pending' do
        expect { submission_attempt.pending! }.to change(submission_attempt, :status).from('failure').to('pending')
      end

      it 'can transition to submitted' do
        expect { submission_attempt.success! }.to change(submission_attempt, :status).from('failure').to('submitted')
      end
    end
  end

  describe 'factory' do
    it 'can create a valid submission attempt' do
      submission_attempt = build(:bgs_submission_attempt)
      expect(submission_attempt).to be_valid
    end

    it 'creates submission attempt with correct attributes' do
      submission_attempt = create(:bgs_submission_attempt, :submitted)
      expect(submission_attempt.status).to eq('submitted')
      expect(submission_attempt.submission).to be_present
      expect(submission_attempt.metadata).to be_present
    end

    it 'creates submission attempt with different traits' do
      pending_attempt = create(:bgs_submission_attempt, :pending)
      failure_attempt = create(:bgs_submission_attempt, :failure)

      expect(pending_attempt.status).to eq('pending')
      expect(failure_attempt.status).to eq('failure')
    end
  end

  describe 'callbacks and validations' do
    it 'validates presence of submission' do
      submission_attempt = build(:bgs_submission_attempt, submission: nil)
      expect(submission_attempt).not_to be_valid
      expect(submission_attempt.errors[:submission]).to include("can't be blank")
    end

    it 'updates submission status when attempt status changes' do
      submission = create(:bgs_submission)
      submission_attempt = create(:bgs_submission_attempt, submission:, status: 'pending')

      expect { submission_attempt.update(status: 'submitted') }
        .to change { submission.reload.latest_status }.from('pending').to('submitted')
    end
  end

  describe '.by_claim_group' do
    let(:parent_claim) { create(:dependents_claim) }
    let(:child_claim1) { create(:add_remove_dependents_claim) }
    let(:child_claim2) { create(:student_claim) }
    let(:other_parent_claim) { create(:dependents_claim) }
    let(:other_child_claim) { create(:add_remove_dependents_claim) }

    let!(:claim_group1) do
      create(:saved_claim_group,
             parent_claim:,
             saved_claim: child_claim1,
             status: 'pending')
    end

    let!(:claim_group2) do
      create(:saved_claim_group,
             parent_claim:,
             saved_claim: child_claim2,
             status: 'pending')
    end

    let!(:other_claim_group) do
      create(:saved_claim_group,
             parent_claim: other_parent_claim,
             saved_claim: other_child_claim,
             status: 'pending')
    end

    let!(:submission1) { create(:bgs_submission, saved_claim: child_claim1) }
    let!(:submission2) { create(:bgs_submission, saved_claim: child_claim2) }
    let!(:other_submission) { create(:bgs_submission, saved_claim: other_child_claim) }

    let!(:attempt1) { create(:bgs_submission_attempt, submission: submission1, status: 'pending') }
    let!(:attempt2) { create(:bgs_submission_attempt, submission: submission2, status: 'pending') }
    let!(:submitted_attempt) { create(:bgs_submission_attempt, submission: submission1, status: 'submitted') }
    let!(:other_attempt) { create(:bgs_submission_attempt, submission: other_submission, status: 'pending') }

    it 'returns submission attempts for a specific parent claim group' do
      results = described_class.by_claim_group(parent_claim.id)

      expect(results).to include(attempt1, attempt2, submitted_attempt)
      expect(results).not_to include(other_attempt)
    end

    it 'can be chained with .pending to filter by status' do
      results = described_class.by_claim_group(parent_claim.id).pending

      expect(results).to include(attempt1, attempt2)
      expect(results).not_to include(submitted_attempt)
      expect(results.pluck(:status).uniq).to eq(['pending'])
    end

    it 'returns empty relation when no matching claim groups exist' do
      non_existent_parent_id = parent_claim.id + 9999
      results = described_class.by_claim_group(non_existent_parent_id)

      expect(results).to be_empty
    end

    it 'is chainable with other scopes' do
      results = described_class.by_claim_group(parent_claim.id).where(id: attempt1.id)

      expect(results).to contain_exactly(attempt1)
    end

    it 'joins through submission, saved_claim, and claim groups correctly' do
      results = described_class.by_claim_group(parent_claim.id)

      expect(results.to_sql).to include('saved_claim_groups')
      expect(results.to_sql).to include('saved_claims')
      expect(results.to_sql).to include('bgs_submissions')
    end
  end

  describe '#claim_type_end_product' do
    context 'when metadata contains claim_type_end_product' do
      let(:submission_attempt) do
        create(:bgs_submission_attempt, metadata: { claim_type_end_product: '130' }.to_json)
      end

      it 'returns the claim_type_end_product value' do
        expect(submission_attempt.claim_type_end_product).to eq('130')
      end
    end

    context 'when metadata does not contain claim_type_end_product' do
      let(:submission_attempt) do
        create(:bgs_submission_attempt, metadata: { form_id: '21-686C' }.to_json)
      end

      it 'returns nil' do
        expect(submission_attempt.claim_type_end_product).to be_nil
      end
    end

    context 'when metadata is nil' do
      let(:submission_attempt) do
        create(:bgs_submission_attempt, metadata: nil)
      end

      it 'returns nil without raising an error' do
        expect(submission_attempt.claim_type_end_product).to be_nil
      end
    end

    context 'when metadata is an empty string' do
      let(:submission_attempt) do
        create(:bgs_submission_attempt, metadata: '')
      end

      it 'returns nil without raising an error' do
        expect(submission_attempt.claim_type_end_product).to be_nil
      end
    end

    context 'when metadata contains complex nested structure' do
      let(:submission_attempt) do
        create(:bgs_submission_attempt)
      end

      before do
        metadata = submission_attempt.metadata || {}
        metadata['claim_type_end_product'] = '134'
        submission_attempt.metadata = metadata.to_json
        submission_attempt.save!
      end

      it 'correctly extracts claim_type_end_product' do
        expect(submission_attempt.claim_type_end_product).to eq('134')
      end
    end
  end
end
