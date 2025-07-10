# frozen_string_literal: true

require 'rails_helper'
require 'accredited_representative_portal/benefits_intake/submission_handler'
require 'accredited_representative_portal/monitor'
require 'accredited_representative_portal/notification_email'

RSpec.describe AccreditedRepresentativePortal::BenefitsIntake::SubmissionHandler do
  let(:handler) { described_class }
  let(:claim) { double(form_id: 'TEST', id: 23) }
  let(:monitor) { double(AccreditedRepresentativePortal::Monitor) }
  let(:notification) { double(AccreditedRepresentativePortal::NotificationEmail) }
  let(:instance) { handler.new('fake-claim-id') }

  before do
    allow(AccreditedRepresentativePortal::SavedClaim).to receive(:find).and_return claim
    allow(AccreditedRepresentativePortal::Monitor).to receive(:new).and_return monitor
    allow(AccreditedRepresentativePortal::NotificationEmail).to receive(:new).with(claim.id).and_return notification
  end

  describe '.pending_attempts' do
    let(:submission_attempt) { double('Lighthouse::SubmissionAttempt') }

    before do
      allow(Lighthouse::SubmissionAttempt).to receive(:joins).with(:submission)
        .and_return(Lighthouse::SubmissionAttempt)
      allow(Lighthouse::SubmissionAttempt).to receive(:where).with(
        status: 'pending',
        'lighthouse_submissions.form_id' =>
          SavedClaim::BenefitsIntake::DependencyClaim::PROPER_FORM_ID
      ).and_return([submission_attempt])
    end

    it 'returns pending submission attempts with the correct form_id' do
      result = handler.pending_attempts
      expect(result).to eq([submission_attempt])
    end
  end

  describe '#on_failure' do
    it 'logs silent failure avoided' do
      expect(notification).to receive(:deliver).with(:error).and_return true
      expect(monitor).to receive(:log_silent_failure_avoided).with(hash_including(claim_id: claim.id), call_location: nil)
      instance.handle(:failure)
    end

    it 'logs silent failure and raises' do
      expect(notification).to receive(:deliver).with(:error).and_return false
      message = "#{handler}: on_failure silent failure not avoided"
      expect(monitor).to receive(:log_silent_failure).with(hash_including(message:), call_location: nil)
      expect { instance.handle(:failure) }.to raise_error message
    end
  end
end
