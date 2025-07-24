# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::NotificationEmail do
  let(:saved_claim) { create(:saved_claim_benefits_intake) }

  describe '#deliver' do
    it 'successfully sends an error email' do
      saved_claim_claimant_representative = FactoryBot.create(:saved_claim_claimant_representative, saved_claim_id: saved_claim.id)
      representative = FactoryBot.create(:representative, representative_id: saved_claim_claimant_representative.accredited_individual_registration_number)

      expect(SavedClaim).to receive(:find).with(saved_claim.id).and_return(saved_claim)

      allow_any_instance_of(described_class).to receive(:email).and_return('example@email.com')

      args = [
        'example@email.com',
        Settings.vanotify.services.accredited_representative_portal.email.error.template_id,
        anything,
        Settings.vanotify.services.accredited_representative_portal.api_key,
        {
          callback_klass: AccreditedRepresentativePortal::NotificationCallback.to_s,
          callback_metadata: anything
        }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(saved_claim.id).deliver(:error)
    end
  end
end
