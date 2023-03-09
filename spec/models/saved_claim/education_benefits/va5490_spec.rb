# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA5490 do
  let(:instance) { FactoryBot.build(:va5490) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-5490')

  describe '#after_submit' do
    let(:user) { create(:user) }

    describe 'sends confirmation email for the 5490' do
      it 'chapter 33' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va5490_chapter33)
        confirmation_number = subject.education_benefits_claim.confirmation_number

        subject.after_submit(user)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'email@example.com',
          'form5490_confirmation_email_template_id',
          {
            'first_name' => 'MARK',
            'benefit' => 'The Fry Scholarship (Chapter 33)',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number,
            'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
          }
        )
      end

      it 'chapter 35' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va5490)
        confirmation_number = subject.education_benefits_claim.confirmation_number

        subject.after_submit(user)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'email@example.com',
          'form5490_confirmation_email_template_id',
          {
            'first_name' => 'MARK',
            'benefit' => 'Survivors’ and Dependents’ Educational Assistance (DEA, Chapter 35)',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number,
            'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
          }
        )
      end
    end
  end
end
