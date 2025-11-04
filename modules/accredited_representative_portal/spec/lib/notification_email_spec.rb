# frozen_string_literal: true

require 'rails_helper'
require 'accredited_representative_portal/notification_email'

RSpec.describe AccreditedRepresentativePortal::NotificationEmail do
  let(:saved_claim) { create(:saved_claim_benefits_intake) }
  let(:vanotify) { double(send_email: true) }

  before do
    # This removes: SHRINE WARNING: Error occurred when attempting to extract image dimensions:
    # #<FastImage::UnknownImageType: FastImage::UnknownImageType>
    allow(FastImage).to receive(:size).and_wrap_original do |original, file|
      if file.respond_to?(:path) && file.path.end_with?('.pdf')
        nil
      else
        original.call(file)
      end
    end
  end

  describe '#deliver' do
    it 'successfully sends an error email' do
      saved_claim_claimant_representative = create(:saved_claim_claimant_representative,
                                                   saved_claim_id: saved_claim.id)
      create(:representative,
             representative_id: saved_claim_claimant_representative.accredited_individual_registration_number)

      expect(SavedClaim).to receive(:find).with(saved_claim.id).and_return(saved_claim)

      allow_any_instance_of(described_class).to receive(:email).and_return('example@email.com')

      expected_personalization = {
        'form_id' => saved_claim.class::PROPER_FORM_ID,
        'confirmation_number' => saved_claim.latest_submission_attempt&.benefits_intake_uuid,
        'date_submitted' => saved_claim.created_at,
        'first_name' => 'Bob',
        'submission_date' => saved_claim.created_at&.strftime('%B %-d, %Y')
      }

      api_key = Settings.vanotify.services.accredited_representative_portal.api_key
      callback_options = {
        callback_klass: AccreditedRepresentativePortal::NotificationCallback.to_s,
        callback_metadata: {
          claim_id: saved_claim_claimant_representative.saved_claim_id,
          email_template_id: 'arp_error_email_template_id',
          email_type: :error, form_id: '21-686C_BENEFITS-INTAKE',
          saved_claim_id: saved_claim_claimant_representative.saved_claim_id,
          service_name: 'accredited_representative_portal'
        }
      }

      expect(VaNotify::Service).to receive(:new).with(api_key, callback_options).and_return(vanotify)
      expect(vanotify).to receive(:send_email).with(
        {
          email_address: 'example@email.com',
          template_id: Settings.vanotify.services.accredited_representative_portal.email.error.template_id,
          personalisation: expected_personalization
        }.compact
      )

      described_class.new(saved_claim.id).deliver(:error)
    end
  end
end
