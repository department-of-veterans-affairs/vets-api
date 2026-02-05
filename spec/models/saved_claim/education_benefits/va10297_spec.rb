# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA10297 do
  let(:instance) { build(:va10297_simple_form) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10297')

  describe '#after_submit' do
    let(:user) { create(:user) }

    before do
      allow(VANotify::EmailJob).to receive(:perform_async)
    end

    describe 'confirmation email for 10297' do
      context 'when the form22_10297_confirmation_email feature flag is disabled' do
        it 'does not send a confirmation email' do
          allow(Flipper).to receive(:enabled?).with(:form22_10297_confirmation_email).and_return(false)

          subject = create(:va10297_simple_form)
          subject.after_submit(user)

          expect(VANotify::EmailJob).not_to have_received(:perform_async)
        end
      end

      context 'when the form22_10297_confirmation_email feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:form22_10297_confirmation_email).and_return(true)
        end

        context 'when the form10297_confirmation_email_with_silent_failure_processing feature flag is disabled' do
          before do
            allow(Flipper)
              .to receive(:enabled?)
              .with(:form10297_confirmation_email_with_silent_failure_processing)
              .and_return(false)
          end

          it 'sends an email without the silent failure callback parameters' do
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

        context 'when the form10297_confirmation_email_with_silent_failure_processing feature flag is enabled' do
          let(:callback_options) do
            {
              callback_metadata: {
                notification_type: 'confirmation',
                form_number: '22-10297',
                statsd_tags: { service: 'submit-10297-form', function: 'form_10297_failure_confirmation_email_sending' }
              }
            }
          end

          before { Flipper.enable(:form10297_confirmation_email_with_silent_failure_processing) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

          it 'sends an email with the silent failure callback parameters' do
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
              },
              Settings.vanotify.services.va_gov.api_key,
              callback_options
            )
          end
        end
      end
    end
  end
end
