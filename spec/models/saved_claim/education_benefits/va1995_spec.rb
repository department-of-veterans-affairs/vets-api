# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA1995 do
  # user isn't used for VA1995 so it doesn't matter whether it's authenticated or not
  let(:user) { nil }
  let(:instance) { build(:va1995) }
  # callback_parms_for_education_benefits_form is defined in lib/saved_claims_spec_helper
  let(:callback_options) { callback_parms_for_education_benefits_form('1995') }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-1995')

  describe '#after_submit' do
    before do
      allow(Flipper).to receive(:enabled?).and_call_original
      allow(Flipper).to receive(:enabled?).with(:form1995_confirmation_email).and_return(true)
      allow(Flipper).to receive(:enabled?)
        .with(:form1995_confirmation_email_with_silent_failure_processing)
        .and_return(true)
    end

    context 'when form1995_confirmation_email flipper is disabled' do
      before { allow(Flipper).to receive(:enabled?).with(:form1995_confirmation_email).and_return(false) }

      it 'returns early without parsing form data' do
        expect(JSON).not_to receive(:parse)
        subject.after_submit(user)
      end
    end

    context 'when form1995_confirmation_email flipper is enabled' do
      before do
        allow(VANotify::EmailJob).to receive(:perform_async)
      end

      context 'happy path (email is not blank)' do
        it 'parses the form data' do
          subject = create(:va1995_full_form)
          expect(JSON).to receive(:parse).with(subject.form).and_call_original
          subject.after_submit(user)
        end
      end

      context 'when the email is blank' do
        it 'returns early without sending the email' do
          form_data_without_email = { 'name' => 'John' }.to_json # no email key
          subject = create(:va1995_full_form)
          allow(subject).to receive(:form).and_return(form_data_without_email)
          expect(subject).not_to receive(:send_confirmation_email)
          subject.after_submit(user)
        end
      end
    end

    context 'flipper enabled for silent failure processing' do
      describe 'sends confirmation email for the 1995 with silent failure processing' do
        before do
          allow(VANotify::EmailJob).to receive(:perform_async)
        end

        context 'when a benefit is selected' do
          it 'sends the email with the selected benefit' do
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
              },
              Settings.vanotify.services.va_gov.api_key,
              callback_options
            )
          end
        end

        context 'when no benefit is selected' do
          it 'sends the email with benefit empty' do
            subject = create(:va1995_full_form)
            parsed_form_data = JSON.parse(subject.form)
            parsed_form_data.delete('benefit') # remove the benefit
            subject.form = parsed_form_data.to_json
            confirmation_number = subject.education_benefits_claim.confirmation_number
            subject.after_submit(user)

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              'test@sample.com',
              'form1995_confirmation_email_template_id',
              {
                'first_name' => 'FIRST',
                'benefit' => '',
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

    context 'flipper disabled for silent failure processing' do
      describe 'sends confirmation email for the 1995 w/out silent failure processing' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:form1995_confirmation_email_with_silent_failure_processing)
            .and_return(false)

          allow(VANotify::EmailJob).to receive(:perform_async)
        end

        context 'when a benefit is selected' do
          it 'sends the email with the selected benefit' do
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

        context 'when no benefit is selected' do
          it 'sends the email with benefit empty' do
            subject = create(:va1995_full_form)
            parsed_form_data = JSON.parse(subject.form)
            parsed_form_data.delete('benefit') # remove the benefit
            subject.form = parsed_form_data.to_json
            confirmation_number = subject.education_benefits_claim.confirmation_number

            subject.after_submit(user)

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              'test@sample.com',
              'form1995_confirmation_email_template_id',
              {
                'first_name' => 'FIRST',
                'benefit' => '',
                'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                'confirmation_number' => confirmation_number,
                'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
              }
            )
          end
        end
      end
    end

    context 'when there is an error with queuing the email' do
      before do
        allow(VANotify::EmailJob).to receive(:perform_async).and_raise(StandardError, 'Test error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error with the expected message' do
        subject = create(:va1995_full_form)

        expected_message =
          'SavedClaim::EducationBenefits::VA1995#send_confirmation_email: ' \
          'Failed to queue confirmation email: Test error'

        expect(Rails.logger).to receive(:error).with(expected_message)
        subject.after_submit(user)
      end
    end
  end
end
