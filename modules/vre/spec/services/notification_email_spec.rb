require 'rails_helper'

RSpec.describe VRE::NotificationEmail do
  let(:saved_claim) { create(:vre_veteran_readiness_employment_claim) }
  let(:notification_email) { described_class.new(saved_claim.id) }
  let(:notification) { double(VRE::NotificationEmail) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(VRE::NotificationEmail).to receive(:new).with(saved_claim.id).and_return(notification)
      expect(notification).to receive(:deliver).with(:action_needed)

      notification_email.deliver(:action_needed)
    end
  end
end
