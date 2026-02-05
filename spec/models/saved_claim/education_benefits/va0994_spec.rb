# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA0994 do
  let(:instance) { build(:va0994_full_form) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-0994')

  describe '#after_submit' do
    let(:user) { create(:user) }

    describe 'confirmation email for 0994' do
      it 'is skipped when feature flag is turned off' do
        Flipper.disable(:form0994_confirmation_email) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va0994_full_form)
        subject.after_submit(user)

        expect(VANotify::EmailJob).not_to have_received(:perform_async)
        Flipper.enable(:form0994_confirmation_email) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      end

      it 'sends v1 when they have applied for VA education benefits previously' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va0994_full_form)
        confirmation_number = subject.education_benefits_claim.confirmation_number

        subject.after_submit(user)
        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'test@test.com',
          'form0994_confirmation_email_template_id',
          {
            'first_name' => 'TEST',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number,
            'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
          }
        )
      end

      it 'sends v2 when they have not applied for VA education benefits previously' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va0994_no_education_benefits)
        confirmation_number = subject.education_benefits_claim.confirmation_number

        subject.after_submit(user)
        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'test@test.com',
          'form0994_extra_action_confirmation_email_template_id',
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
