# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA1990 do
  let(:instance) { build(:va1990) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-1990')

  describe '#after_submit' do
    let(:user) { create(:user) }

    describe 'confirmation email for the 1990' do
      it 'is sent to authenticated users' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va1990_chapter33)
        subject.after_submit(user)

        expect(VANotify::EmailJob).to have_received(:perform_async)
      end

      it 'is sent to unauthenticated users' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va1990_chapter33)
        subject.after_submit(nil)

        expect(VANotify::EmailJob).to have_received(:perform_async)
      end

      it 'is skipped when feature flag is turned off' do
        Flipper.disable(:form1990_confirmation_email) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va1990_chapter33)
        subject.after_submit(user)

        expect(VANotify::EmailJob).not_to have_received(:perform_async)
        Flipper.enable(:form1990_confirmation_email) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      end

      it 'chapter 33' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va1990_chapter33)
        confirmation_number = subject.education_benefits_claim.confirmation_number

        subject.after_submit(nil)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'email@example.com',
          'form1990_confirmation_email_template_id',
          {
            'first_name' => 'MARK',
            'benefit_relinquished' => '',
            'benefits' => 'Post-9/11 GI Bill (Chapter 33)',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number,
            'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
          }
        )
      end

      it 'with relinquished' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va1990_with_relinquished)
        confirmation_number = subject.education_benefits_claim.confirmation_number

        subject.after_submit(nil)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'email@example.com',
          'form1990_confirmation_email_template_id',
          {
            'first_name' => 'MARK',
            'benefit_relinquished' => "__Benefits Relinquished:__\n^Montgomery GI Bill (MGIB-AD, Chapter 30)",
            'benefits' => "Post-9/11 GI Bill (Chapter 33)\n\n^Montgomery GI Bill Selected Reserve " \
                          "(MGIB-SR or Chapter 1606) Educational Assistance Program\n\n^Post-Vietnam " \
                          'Era Veterans’ Educational Assistance Program (VEAP or chapter 32)',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number,
            'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
          }
        )
      end
    end
  end
end
