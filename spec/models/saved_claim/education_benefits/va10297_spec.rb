# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA10297 do
  let(:instance) { build(:va10297_simple_form) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10297')

  describe '#after_submit' do
    let(:user) { create(:user) }

    describe 'confirmation email for 10297' do
      it 'is skipped when feature flag is turned off' do
        allow(Flipper).to receive(:enabled?).with(:form22_10297_confirmation_email).and_return(false)
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va10297_simple_form)
        subject.after_submit(user)

        expect(VANotify::EmailJob).not_to have_received(:perform_async)
      end

      it 'sends an email when they have applied for VA education benefits previously' do
        allow(Flipper).to receive(:enabled?).with(:form22_10297_confirmation_email).and_return(true)
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va10297_simple_form)
        confirmation_number = subject.education_benefits_claim.confirmation_number

        subject.after_submit(user)
        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'test@test.com',
          'form10297_confirmation_email_template_id',
          {
            'first_name' => 'TEST',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number,
            'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
          }
        )
      end
    end
  end
end
