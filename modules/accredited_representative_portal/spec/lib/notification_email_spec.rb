# frozen_string_literal: true

require 'rails_helper'
require 'accredited_representative_portal/notification_email'

RSpec.describe AccreditedRepresentativePortal::NotificationEmail do
  let(:saved_claim) { create(:saved_claim_benefits_intake) }

  describe '#deliver' do
    it 'successfully sends an error email' do
      saved_claim_claimant_representative = create(:saved_claim_claimant_representative,
                                                   saved_claim_id: saved_claim.id)
      create(:representative,
             representative_id: saved_claim_claimant_representative.accredited_individual_registration_number)

      expect(SavedClaim).to receive(:find).with(saved_claim.id).and_return(saved_claim)

      allow_any_instance_of(described_class).to receive(:email).and_return('example@email.com')

      expected_personalization = hash_including(
        'form_id' => saved_claim.class::PROPER_FORM_ID,
        'confirmation_number' => saved_claim.confirmation_number,
        'first_name' => anything,
        'submission_date' => anything
      )

      args = [
        'example@email.com',
        Settings.vanotify.services.accredited_representative_portal.email.error.template_id,
        expected_personalization,
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
