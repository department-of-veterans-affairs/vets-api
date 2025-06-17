# frozen_string_literal: true

require 'rails_helper'
require 'pensions/benefits_intake/submission_handler'
require 'pensions/monitor'
require 'pensions/notification_email'

Rspec.describe Pensions::BenefitsIntake::SubmissionHandler do
  let(:handler) { Pensions::BenefitsIntake::SubmissionHandler }
  let(:claim) { build(:pensions_saved_claim) }
  let(:monitor) { double(Pensions::Monitor) }
  let(:notification) { double(Pensions::NotificationEmail) }
  let(:instance) { handler.new('fake-claim-id') }

  before do
    allow(Pensions::SavedClaim).to receive(:find).and_return claim
    allow(Pensions::Monitor).to receive(:new).and_return monitor
    allow(Pensions::NotificationEmail).to receive(:new).with(claim.id).and_return notification
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
