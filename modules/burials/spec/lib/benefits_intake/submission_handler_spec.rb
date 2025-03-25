# frozen_string_literal: true

require 'rails_helper'
require 'burials/benefits_intake/submission_handler'
require 'burials/monitor'
require 'burials/notification_email'

Rspec.describe Burials::BenefitsIntake::SubmissionHandler do
  let(:handler) { Burials::BenefitsIntake::SubmissionHandler }
  let(:claim) { double(form_id: 'TEST', id: 23) }
  let(:monitor) { double(Burials::Monitor) }
  let(:notification) { double(Burials::NotificationEmail) }
  let(:instance) { handler.new('fake-claim-id') }

  before do
    allow(Burials::SavedClaim).to receive(:find).and_return claim
    allow(Burials::Monitor).to receive(:new).and_return monitor
    allow(Burials::NotificationEmail).to receive(:new).with(claim.id).and_return notification
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
