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

    before do
      allow(attempt).to receive(:status_change_hash).and_return({ id: 123 })
    end

    describe '#fail!' do
      it 'sets status to failure and logs error' do
        expect(attempt).to receive(:failure!)
        expect(Rails.logger).to receive(:error).with(hash_including(message: 'Lighthouse Submission Attempt failed'))
        attempt.fail!
      end
    end

    describe '#manual!' do
      it 'sets status to manually and logs warning' do
        expect(attempt).to receive(:manually!)
        expect(Rails.logger).to receive(:warn)
          .with(hash_including(message: 'Lighthouse Submission Attempt is being manually remediated'))
        attempt.manual!
      end
    end

    describe '#vbms!' do
      it 'updates status to vbms and logs info' do
        expect(attempt).to receive(:update).with(status: :vbms)
        expect(Rails.logger).to receive(:info)
          .with(hash_including(message: 'Lighthouse Submission Attempt went to vbms'))
        attempt.vbms!
      end
    end

    describe '#pending!' do
      it 'updates status to pending and logs info' do
        expect(attempt).to receive(:update).with(status: :pending)
        expect(Rails.logger).to receive(:info).with(hash_including(message: 'Lighthouse Submission Attempt is pending'))
        attempt.pending!
      end
    end

    describe '#success!' do
      it 'sets status to submitted and logs info' do
        expect(attempt).to receive(:submitted!)
        expect(Rails.logger).to receive(:info)
          .with(hash_including(message: 'Lighthouse Submission Attempt is submitted'))
        attempt.success!
      end
    end
  end
end
