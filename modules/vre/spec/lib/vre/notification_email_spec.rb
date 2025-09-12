# frozen_string_literal: true

require 'rails_helper'
require 'vre/notification_email'

RSpec.describe VRE::NotificationEmail do
  let(:saved_claim) { create(:veteran_readiness_employment_claim) }
  let(:notification_email) { described_class.new(saved_claim.id) }
  let(:notification) { double(VRE::NotificationEmail) }

  describe '#deliver' do
    let(:saved_claim) { create(:veteran_readiness_employment_claim) }
    let(:notification_email) { described_class.new(saved_claim.id) }

    it 'successfully sends an email' do
      expect(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).with(saved_claim.id).and_return(saved_claim)

      args = [
        saved_claim.email,
        Settings.vanotify.services.veteran_readiness_and_employment.email.confirmation_vbms.template_id,
        anything,
        Settings.vanotify.services.veteran_readiness_and_employment.api_key,
        { callback_klass: anything,
          callback_metadata: anything }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      notification_email.deliver(:confirmation_vbms)
    end
  end
end
