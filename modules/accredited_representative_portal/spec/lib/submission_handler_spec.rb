# frozen_string_literal: true

require 'rails_helper'
require 'accredited_representative_portal/submission_handler'
require 'accredited_representative_portal/monitor'
require 'accredited_representative_portal/notification_email'

RSpec.describe AccreditedRepresentativePortal::SubmissionHandler do
  let(:handler) { described_class }
  let(:claim) { create(:saved_claim_benefits_intake) }
  let(:instance) { handler.new(claim.id) }

  before do
    # This removes: SHRINE WARNING: Error occurred when attempting to extract image dimensions:
    # #<FastImage::UnknownImageType: FastImage::UnknownImageType>
    allow(FastImage).to receive(:size).and_wrap_original do |original, file|
      if file.respond_to?(:path) && file.path.end_with?('.pdf')
        nil
      else
        original.call(file)
      end
    end
  end

  describe '.pending_attempts' do
    let(:form_submission) do
      create(:form_submission, saved_claim: claim, form_type: '21-686C_BENEFITS-INTAKE')
    end
    let!(:submission_attempt) do
      create(:form_submission_attempt, form_submission:, aasm_state: 'pending')
    end

    before do
      stub_const(
        'AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::FORM_TYPES',
        [claim.class]
      )
    end

    it 'returns pending form submission attempts for correct form_ids' do
      result = handler.pending_attempts
      expect(result).to contain_exactly(submission_attempt)
    end
  end

  describe '#on_failure' do
    let(:monitor) { instance_double(AccreditedRepresentativePortal::Monitor) }
    let(:notification) { instance_double(AccreditedRepresentativePortal::NotificationEmail) }

    before do
      allow(AccreditedRepresentativePortal::Monitor).to receive(:new).with(claim:).and_return(monitor)
      allow(AccreditedRepresentativePortal::NotificationEmail).to receive(:new).with(claim.id).and_return(notification)
      allow(SavedClaim).to receive(:find).and_return(claim)
    end

    it 'logs silent failure avoided' do
      expect(notification).to receive(:deliver).with(:error).and_return true
      expect(monitor).to receive(:log_silent_failure_avoided).with(
        hash_including(claim_id: claim.id),
        call_location: nil
      )

      instance.handle(:failure)
    end

    it 'logs silent failure and raises' do
      expect(notification).to receive(:deliver).with(:error).and_return false
      message = "#{handler}: on_failure silent failure not avoided"
      expect(monitor).to receive(:log_silent_failure).with(
        hash_including(message:),
        call_location: nil
      )

      expect { instance.handle(:failure) }.to raise_error message
    end
  end

  describe '#on_success' do
    let(:notification) { instance_double(AccreditedRepresentativePortal::NotificationEmail) }

    before do
      allow(AccreditedRepresentativePortal::NotificationEmail).to receive(:new).with(claim.id).and_return(notification)
      allow(SavedClaim).to receive(:find).and_return(claim)
    end

    it 'sends success notification email' do
      expect(notification).to receive(:deliver).with(:received)

      instance.handle(:success)
    end

    it 'calls super after sending notification' do
      allow(notification).to receive(:deliver).with(:received)

      expect_any_instance_of(BenefitsIntake::SubmissionHandler::SavedClaim).to receive(:on_success)

      instance.handle(:success)
    end
  end
end
