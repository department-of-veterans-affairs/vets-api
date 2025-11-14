# frozen_string_literal: true

require 'rails_helper'
require 'increase_compensation/benefits_intake/submission_handler'
require 'increase_compensation/monitor'
require 'increase_compensation/notification_email'

RSpec.describe IncreaseCompensation::BenefitsIntake::SubmissionHandler do
  let(:handler) { IncreaseCompensation::BenefitsIntake::SubmissionHandler }
  let(:claim) { instance_double(IncreaseCompensation::SavedClaim, form_id: 'TEST', id: 23) }
  let(:monitor) { instance_double(IncreaseCompensation::Monitor) }
  let(:notification) { instance_double(IncreaseCompensation::NotificationEmail) }
  let(:instance) { handler.new('fake-claim-id') }

  before do
    allow(IncreaseCompensation::SavedClaim).to receive(:find).and_return claim
    allow(IncreaseCompensation::Monitor).to receive(:new).and_return monitor
    allow(IncreaseCompensation::NotificationEmail).to receive(:new).with(claim.id).and_return notification
  end

  describe '.pending_attempts' do
    let(:submission_attempt) { instance_double(Lighthouse::SubmissionAttempt) }
    let(:submission) { instance_double(Lighthouse::Submission, form_id: '21-8940V1') }

    before do
      allow(Lighthouse::SubmissionAttempt).to receive(:joins).with(:submission)
                                                             .and_return(Lighthouse::SubmissionAttempt)
      allow(Lighthouse::SubmissionAttempt).to receive(:where).with(status: 'pending',
                                                                   'lighthouse_submissions.form_id' => '21-8940V1')
                                                             .and_return([submission_attempt])
    end

    it 'returns pending submission attempts with the correct form_id' do
      result = handler.pending_attempts
      expect(result).to eq([submission_attempt])
    end

    it 'queries with the correct status and form_id' do
      expect(Lighthouse::SubmissionAttempt).to receive(:joins).with(:submission)
      expect(Lighthouse::SubmissionAttempt).to receive(:where).with(status: 'pending',
                                                                    'lighthouse_submissions.form_id' => '21-8940V1')
      handler.pending_attempts
    end
  end

  describe '#on_failure' do
    it 'logs silent failure avoided' do
      expect(notification).to receive(:deliver).with(:error).and_return true
      expect(monitor).to receive(:log_silent_failure_avoided).with(hash_including(claim_id: claim.id),
                                                                   call_location: nil)
      instance.handle(:failure)
    end

    it 'logs silent failure' do
      expect(notification).to receive(:deliver).with(:error).and_return false
      message = "#{handler}: on_failure silent failure not avoided"
      expect(monitor).to receive(:log_silent_failure).with(hash_including(message:), call_location: nil)
      expect { instance.handle(:failure) }.to raise_error message
    end
  end

  describe '#on_success' do
    it 'sends a received email' do
      expect(notification).to receive(:deliver).with(:received)
      expect(instance.handle(:success)).to be true
    end
  end

  describe '#on_stale' do
    it 'does nothing' do
      # pass thru for coverage
      expect(instance.handle(:stale)).to be true
    end
  end
end
