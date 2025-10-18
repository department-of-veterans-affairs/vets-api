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
end
