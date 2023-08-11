# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA5495 do
  let(:instance) { FactoryBot.build(:va5495) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-5495')

  describe '#after_submit' do
    let(:user) { create(:user) }

    it 'sends confirmation email for the 5495' do
      allow(VANotify::EmailJob).to receive(:perform_async)

      subject = create(:va5495_with_email)
      confirmation_number = subject.education_benefits_claim.confirmation_number

      subject.after_submit(user)

      expect(VANotify::EmailJob).to have_received(:perform_async).with(
        'email@example.com',
        'form5495_confirmation_email_template_id',
        {
          'first_name' => 'MARK',
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'confirmation_number' => confirmation_number,
          'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
        }
      )
    end
  end
end
