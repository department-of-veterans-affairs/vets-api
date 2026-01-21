# frozen_string_literal: true

require 'rails_helper'
require 'support/models/shared_examples/submission_attempt'

RSpec.describe ClaimsEvidenceApi::SubmissionAttempt, type: :model do
  let(:saved_claim) { create(:dependents_claim) }
  let(:submission) { create(:claims_evidence_submission, saved_claim:) }
  let(:submission_attempt) { build(:claims_evidence_submission_attempt, submission:) }

  it_behaves_like 'a SubmissionAttempt model'

  describe 'database configuration' do
    it 'uses the correct table name' do
      expect(described_class.table_name).to eq('claims_evidence_api_submission_attempts')
    end
  end

  describe 'enums' do
    it 'has status enum with correct values' do
      expect(described_class.statuses).to eq({
                                               'pending' => 'pending',
                                               'accepted' => 'accepted',
                                               'failed' => 'failed'
                                             })
    end

    it 'responds to status enum methods' do
      attempt = build(:claims_evidence_submission_attempt, submission:)
      expect(attempt).to respond_to(:pending?)
      expect(attempt).to respond_to(:accepted?)
      expect(attempt).to respond_to(:failed?)
    end

    describe 'status values' do
      it 'has correct enum values' do
        expect(described_class.statuses).to eq({
                                                 'pending' => 'pending',
                                                 'accepted' => 'accepted',
                                                 'failed' => 'failed'
                                               })
      end
    end
  end

  describe '#fail!' do
    let(:submission_attempt) { create(:claims_evidence_submission_attempt, status: 'pending', submission:) }
    let(:error) { StandardError.new('Test error message') }
    let(:monitor) { instance_double(ClaimsEvidenceApi::Monitor::Record) }

    before do
      allow(submission_attempt).to receive(:monitor).and_return(monitor)
      allow(monitor).to receive(:track_event)
    end

    it 'updates error_message with the error message' do
      submission_attempt.fail!(error:)
      expect(submission_attempt.error_message).to eq('Test error message')
    end

    it 'sets status to failed' do
      submission_attempt.fail!(error:)
      expect(submission_attempt.status).to eq('failed')
    end

    it 'handles nil error gracefully' do
      submission_attempt.fail!(error: nil)
      expect(submission_attempt.error_message).to be_nil
      expect(submission_attempt.status).to eq('failed')
    end

    it 'tracks the event with monitor' do
      expect(monitor).to receive(:track_event).with(
        :fail,
        hash_including(
          :id,
          :status,
          :submission_id,
          :saved_claim_id,
          :form_id
        )
      )
      submission_attempt.fail!(error:)
    end
  end

  describe '#pending!' do
    let(:submission_attempt) { create(:claims_evidence_submission_attempt, status: 'accepted', submission:) }
    let(:monitor) { instance_double(ClaimsEvidenceApi::Monitor::Record) }

    before do
      allow(submission_attempt).to receive(:monitor).and_return(monitor)
      allow(monitor).to receive(:track_event)
    end

    it 'sets status to pending' do
      submission_attempt.pending!
      expect(submission_attempt.status).to eq('pending')
    end

    it 'tracks the status change with monitor' do
      expect(monitor).to receive(:track_event).with(
        :pending,
        hash_including(
          :id,
          :status,
          :submission_id,
          :saved_claim_id,
          :form_id
        )
      )
      submission_attempt.pending!
    end
  end

  describe '#success!' do
    let(:submission_attempt) { create(:claims_evidence_submission_attempt, status: 'pending', submission:) }
    let(:monitor) { instance_double(ClaimsEvidenceApi::Monitor::Record) }

    before do
      allow(submission_attempt).to receive(:monitor).and_return(monitor)
      allow(monitor).to receive(:track_event)
    end

    it 'sets status to accepted' do
      submission_attempt.success!
      expect(submission_attempt.status).to eq('accepted')
    end

    it 'tracks the status change with monitor' do
      expect(monitor).to receive(:track_event).with(
        :success,
        hash_including(
          :id,
          :status,
          :submission_id,
          :saved_claim_id,
          :form_id
        )
      )
      submission_attempt.success!
    end
  end

  describe '#tracking_attributes' do
    let(:saved_claim) { create(:dependents_claim) }
    let(:submission_attempt) { create(:claims_evidence_submission_attempt, status: 'pending', submission:) }

    it 'returns data for tracking' do
      hash = submission_attempt.tracking_attributes
      expect(hash[:id]).to eq(submission_attempt.id)
      expect(hash[:submission_id]).to eq(submission_attempt.submission.id)
      expect(hash[:saved_claim_id]).to eq(saved_claim.id)
      expect(hash[:form_id]).to eq(saved_claim.form_id)
    end
  end
end
