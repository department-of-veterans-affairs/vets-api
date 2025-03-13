# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_intake/submission_handler/saved_claim'

Rspec.describe BenefitsIntake::SubmissionHandler::SavedClaim do
  let(:handler) { BenefitsIntake::SubmissionHandler::SavedClaim }
  let(:claim) { double(form_id: 'TEST', id: 23) }
  let(:monitor) { double(ZeroSilentFailures::Monitor) }

  before do
    allow(SavedClaim).to receive(:find).and_return claim
    allow(ZeroSilentFailures::Monitor).to receive(:new).with('lighthouse-benefits-intake').and_return monitor
  end

  describe '#on_failure' do
    it 'logs silent failure avoided' do
      instance = handler.new('fake-claim-id')
      expect(instance).to receive(:avoided).and_return true
      expect(monitor).to receive(:log_silent_failure_avoided).with(hash_including(claim_id: claim.id),
                                                                   call_location: nil)

      instance.handle(:failure)
    end

    it 'logs silent failure' do
      message = "#{handler}: on_failure silent failure not avoided"
      expect(monitor).to receive(:log_silent_failure).with(hash_including(message:), call_location: nil)

      expect { handler.new('fake-claim-id').handle(:failure) }.to raise_error message
    end
  end

  describe '#on_success' do
    it 'sends a received email' do
      # pass thru for coverage
      expect(handler.new('fake-claim-id').handle(:success)).to be true
    end
  end

  describe '#on_stale' do
    it 'does nothing' do
      # pass thru for coverage
      expect(handler.new('fake-claim-id').handle(:stale)).to be true
    end
  end
end
