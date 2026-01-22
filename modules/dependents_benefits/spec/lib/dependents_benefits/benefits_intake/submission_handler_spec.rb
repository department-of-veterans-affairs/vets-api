# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/benefits_intake/submission_handler'
require 'dependents_benefits/monitor'

Rspec.describe DependentsBenefits::BenefitsIntake::SubmissionHandler do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    allow(DependentsBenefits::PrimaryDependencyClaim).to receive(:find).and_return claim
    allow(DependentsBenefits::Monitor).to receive(:new).and_return monitor
  end

  let(:handler) { DependentsBenefits::BenefitsIntake::SubmissionHandler }
  let(:claim) { build(:dependents_claim) }
  let(:monitor) { double(DependentsBenefits::Monitor) }
  let(:instance) { handler.new('fake-claim-id') }

  describe '.pending_attempts' do
    let(:submission_attempt) { double('Lighthouse::SubmissionAttempt') }
    let(:submission) { double('Lighthouse::Submission', form_id: '686C-674-V2') }

    before do
      allow(Lighthouse::SubmissionAttempt).to receive(:joins).with(:submission)
                                                             .and_return(Lighthouse::SubmissionAttempt)
      allow(Lighthouse::SubmissionAttempt).to receive(:where).with(status: 'pending',
                                                                   'lighthouse_submissions.form_id' => '686C-674-V2')
                                                             .and_return([submission_attempt])
    end

    it 'returns pending submission attempts with the correct form_id' do
      result = handler.pending_attempts
      expect(result).to eq([submission_attempt])
    end

    it 'queries with the correct status and form_id' do
      expect(Lighthouse::SubmissionAttempt).to receive(:joins).with(:submission)
      expect(Lighthouse::SubmissionAttempt).to receive(:where).with(status: 'pending',
                                                                    'lighthouse_submissions.form_id' => '686C-674-V2')
      handler.pending_attempts
    end
  end

  describe '#on_stale' do
    it 'does nothing' do
      # pass thru for coverage
      expect(instance.handle(:stale)).to be true
    end
  end

  describe 'private methods' do
    describe '#claim_class' do
      it 'returns DependentsBenefits::PrimaryDependencyClaim' do
        expect(instance.send(:claim_class)).to eq(DependentsBenefits::PrimaryDependencyClaim)
      end
    end

    describe '#monitor' do
      it 'returns an instance of DependentsBenefits::Monitor' do
        expect(instance.send(:monitor)).to eq(monitor)
      end
    end

    describe '#notification_email' do
      let(:notification_email) { double('Dependents::NotificationEmail') }

      before do
        allow(Dependents::NotificationEmail).to receive(:new).with(claim.id).and_return(notification_email)
      end

      it 'returns an instance of Dependents::NotificationEmail' do
        expect(instance.send(:notification_email)).to eq(notification_email)
      end
    end

    describe '#on_failure' do
      let(:notification_email) { double('Dependents::NotificationEmail') }

      before do
        allow(Dependents::NotificationEmail).to receive(:new).with(claim.id).and_return(notification_email)
        allow(notification_email).to receive(:send_error_notification).and_return(true)
        allow_any_instance_of(BenefitsIntake::SubmissionHandler::SavedClaim).to receive(:on_failure).and_return(true)
      end

      it 'sends an error notification email' do
        expect(notification_email).to receive(:send_error_notification)
        instance.send(:on_failure)
      end
    end

    describe '#on_success' do
      let(:notification_email) { double('Dependents::NotificationEmail') }

      before do
        allow(Dependents::NotificationEmail).to receive(:new).with(claim.id).and_return(notification_email)
        allow(notification_email).to receive(:send_received_notification).and_return(true)
        allow_any_instance_of(BenefitsIntake::SubmissionHandler::SavedClaim).to receive(:on_success).and_return(true)
      end

      it 'sends a received notification email' do
        expect(notification_email).to receive(:send_received_notification)
        instance.send(:on_success)
      end
    end
  end
end
