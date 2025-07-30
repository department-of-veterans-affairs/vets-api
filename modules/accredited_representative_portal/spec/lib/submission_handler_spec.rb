# frozen_string_literal: true

require 'rails_helper'
require 'accredited_representative_portal/submission_handler'
require 'accredited_representative_portal/monitor'
require 'accredited_representative_portal/notification_email'

RSpec.describe AccreditedRepresentativePortal::SubmissionHandler do
  let(:handler) { described_class }
  let(:claim) do
    instance_double(
      SavedClaim,
      form_id: 'TEST',
      id: 23,
      class: AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim
    )
  end
  let(:monitor) { instance_double(AccreditedRepresentativePortal::Monitor) }
  let(:notification) { instance_double(AccreditedRepresentativePortal::NotificationEmail) }
  let(:instance) { handler.new('fake-claim-id') }

  before do
    allow(SavedClaim).to receive(:find).with('fake-claim-id').and_return(claim)
    allow(AccreditedRepresentativePortal::Monitor).to receive(:new).with(claim:).and_return(monitor)
    allow(AccreditedRepresentativePortal::NotificationEmail)
      .to receive(:new).with(claim.id).and_return(notification)
  end

  describe '.pending_attempts' do
    let(:submission_attempt) { instance_double(Lighthouse::SubmissionAttempt) }
    let(:mock_relation) { instance_double(ActiveRecord::Relation) }

    before do
      mock_form_class = double('DependencyClaim', PROPER_FORM_ID: '21-686c')
      stub_const('AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::FORM_TYPES', [mock_form_class])

      allow(Lighthouse::SubmissionAttempt).to receive(:joins).with(:submission).and_return(mock_relation)

      allow(mock_relation).to receive(:where).with(status: 'pending').and_return(mock_relation)
      allow(mock_relation).to receive(:where).with('lighthouse_submissions.form_id': ['21-686c'])
                                             .and_return([submission_attempt])
    end

    it 'returns pending submission attempts with the correct form_id list' do
      result = handler.pending_attempts
      expect(result).to eq([submission_attempt])
    end
  end

  describe '#on_failure' do
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
end
