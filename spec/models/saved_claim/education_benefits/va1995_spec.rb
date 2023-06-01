# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA1995 do
  let(:instance) { FactoryBot.build(:va1995) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-1995')

  describe '#after_submit' do
    let(:user) { create(:user) }

    describe 'sends confirmation email for the 1995' do
      it 'successfully submits' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va1995_full_form)
        confirmation_number = subject.education_benefits_claim.confirmation_number

        subject.after_submit(user)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'test@sample.com',
          'form1995_confirmation_email_template_id',
          {
            'first_name' => 'FIRST',
            'benefit' => 'Transfer of Entitlement Program (TOE)',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number,
            'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
          }
        )
      end
    end
  end
end
