# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA1990e do
  let(:instance) { FactoryBot.build(:va1990e) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-1990E')

  describe '#after_submit' do
    let(:user) { create(:user) }

    describe 'confirmation email for the 1990e' do
      it 'is sent to authenticated users' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va1990e_with_email)
        subject.after_submit(user)

        expect(VANotify::EmailJob).to have_received(:perform_async)
      end

      it 'is sent to unauthenticated users' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va1990e_with_email)
        subject.after_submit(nil)

        expect(VANotify::EmailJob).to have_received(:perform_async)
      end

      it 'is skipped when feature flag is turned off' do
        Flipper.disable(:form1990e_confirmation_email)
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va1990e_with_email)
        subject.after_submit(user)

        expect(VANotify::EmailJob).not_to have_received(:perform_async)
        Flipper.enable(:form1990e_confirmation_email)
      end

      it 'sends with form data' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va1990e_with_email)
        subject.after_submit(user)
        confirmation_number = subject.education_benefits_claim.confirmation_number

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'email@example.com',
          'form1990e_confirmation_email_template_id',
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
end
