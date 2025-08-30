# frozen_string_literal: true

require 'rails_helper'
require 'vre/notification_email'

RSpec.describe VRE::NotificationEmail do
  describe '#deliver' do
    let(:saved_claim) { create(:veteran_readiness_employment_claim) }
    let(:notification_email) { described_class.new(saved_claim.id) }

    %i[confirmation_vbms confirmation_lighthouse error].each do |email_type|
      it 'successfully sends an email' do
        expect(SavedClaim::VeteranReadinessEmploymentClaim)
          .to receive(:find).with(saved_claim.id).and_return(saved_claim)

        args = [
          saved_claim.email,
          Settings.vanotify.services.veteran_readiness_and_employment.email[email_type].template_id,
          anything,
          Settings.vanotify.services.veteran_readiness_and_employment.api_key,
          { callback_klass: anything,
            callback_metadata: anything }
        ]
        expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

        notification_email.deliver(email_type)
      end
    end
  end
end
