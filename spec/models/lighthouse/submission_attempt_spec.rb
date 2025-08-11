# frozen_string_literal: true

require 'rails_helper'
require 'support/models/shared_examples/submission_attempt'

RSpec.describe Lighthouse::SubmissionAttempt, type: :model do
  it_behaves_like 'a SubmissionAttempt model'

  describe 'associations' do
    it {
      expect(subject).to belong_to(:submission).class_name('Lighthouse::Submission')
                                               .with_foreign_key(:lighthouse_submission_id)
                                               .inverse_of(:submission_attempts)
    }
  end

  describe 'status transition methods' do
    let(:submission) { build_stubbed(:lighthouse_submission) }
    let(:attempt) { described_class.new(submission:) }
    let(:monitor_double) { instance_double(Logging::Monitor, track_request: nil) }

    before do
      allow(attempt).to receive_messages(
        status_change_hash: { id: 123 },
        monitor: monitor_double
      )
    end

    describe '#fail!' do
      it 'sets status to failure and logs error' do
        expect(attempt).to receive(:failure!)
        expect(monitor_double).to receive(:track_request).with(
          :error,
          'Lighthouse Submission Attempt failed',
          Lighthouse::SubmissionAttempt::STATS_KEY,
          hash_including(message: 'Lighthouse Submission Attempt failed', id: 123)
        )
        attempt.fail!
      end
    end

    describe '#manual!' do
      it 'sets status to manually and logs warning' do
        expect(attempt).to receive(:manually!)
        expect(monitor_double).to receive(:track_request).with(
          :warn,
          'Lighthouse Submission Attempt is being manually remediated',
          Lighthouse::SubmissionAttempt::STATS_KEY,
          hash_including(message: 'Lighthouse Submission Attempt is being manually remediated', id: 123)
        )
        attempt.manual!
      end
    end

    describe '#vbms!' do
      it 'updates status to vbms and logs info' do
        expect(attempt).to receive(:update).with(status: :vbms)
        expect(monitor_double).to receive(:track_request).with(
          :info,
          'Lighthouse Submission Attempt went to vbms',
          Lighthouse::SubmissionAttempt::STATS_KEY,
          hash_including(message: 'Lighthouse Submission Attempt went to vbms', id: 123)
        )
        attempt.vbms!
      end
    end

    describe '#pending!' do
      it 'updates status to pending and logs info' do
        expect(attempt).to receive(:update).with(status: :pending)
        expect(monitor_double).to receive(:track_request).with(
          :info,
          'Lighthouse Submission Attempt is pending',
          Lighthouse::SubmissionAttempt::STATS_KEY,
          hash_including(message: 'Lighthouse Submission Attempt is pending', id: 123)
        )
        attempt.pending!
      end
    end

    describe '#success!' do
      it 'sets status to submitted and logs info' do
        expect(attempt).to receive(:submitted!)
        expect(monitor_double).to receive(:track_request).with(
          :info,
          'Lighthouse Submission Attempt is submitted',
          Lighthouse::SubmissionAttempt::STATS_KEY,
          hash_including(message: 'Lighthouse Submission Attempt is submitted', id: 123)
        )
        attempt.success!
      end
    end
  end
end
