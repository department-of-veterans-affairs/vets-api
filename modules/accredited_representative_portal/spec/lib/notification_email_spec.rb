# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::NotificationEmail do
  let(:saved_claim) { create(:accredited_representative_portal_saved_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(AccreditedRepresentativePortal::SavedClaim).to receive(:find).with(23).and_return saved_claim

      args = [
        saved_claim.email,
        Settings.accredited_representative_portal.notify.email.received.template_id,
        anything,
        Settings.accredited_representative_portal.notify.api_key,
        {
          callback_klass: AccreditedRepresentativePortal::NotificationCallback.to_s,
          callback_metadata: anything
        }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:received)
    end
  end
end

# no factory class
