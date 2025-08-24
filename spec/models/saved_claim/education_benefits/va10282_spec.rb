# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA10282 do
  let(:instance) { build(:va10282) }
  let(:callback_options) do
    {
      callback_metadata: {
        notification_type: 'confirmation',
        form_number: '22-10282',
        statsd_tags: { service: 'submit-10282-form', function: 'form_10282_failure_confirmation_email_sending' }
      }
    }
  end

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10282')

  describe '#after_submit' do
    before do
      allow(Flipper).to receive(:enabled?).and_call_original
      allow(Flipper).to receive(:enabled?).with(:form10282_confirmation_email).and_return(true)
    end

    context 'when form10282_confirmation_email flipper is disabled' do
      let(:user) { create(:user) }

      before { allow(Flipper).to receive(:enabled?).with(:form10282_confirmation_email).and_return(false) }

      it 'returns early without parsing form data' do
        expect(JSON).not_to receive(:parse)
        subject.after_submit(user)
      end
    end

    context 'when flipper is enabled' do
      let(:user) { create(:user) }

      before do
        allow(VANotify::EmailJob).to receive(:perform_async)
      end

      context 'happy path (email is not blank)' do
        it 'parses the form data' do
          subject = create(:va10282)

          expect(JSON).to receive(:parse).with(subject.form).and_call_original

          subject.after_submit(user)
        end
      end

      context 'when the email is blank' do
        let(:user) { nil } # unauthenticated so no user profile email

        it 'returns early without sending the email' do
          form_data_without_email = { 'name' => 'John' }.to_json # no email key

          subject = create(:va10282)
          allow(subject).to receive(:form).and_return(form_data_without_email)

          expect(subject).not_to receive(:send_confirmation_email)

          subject.after_submit(user)
        end
      end
    end

    context 'authenticated user (logged in)' do
      # email will be picked up from the user profile of the logged in user
      let(:user) { create(:user) }

      describe 'sends confirmation email for the 10282' do
        before do
          allow(VANotify::EmailJob).to receive(:perform_async)
        end

        it 'sends the confirmation email' do
          subject = create(:va10282)
          confirmation_number = subject.education_benefits_claim.confirmation_number

          subject.after_submit(user)

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            user.email,
            'form10282_confirmation_email_template_id',
            {
              'first_name' => 'FIRST',
              'benefit' => 'Transfer of Entitlement Program (TOE)',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => confirmation_number
            },
            Settings.vanotify.services.va_gov.api_key,
            callback_options
          )
        end
      end
    end

    context 'unauthenticated user (not logged in)' do
      let(:user) { nil }

      # email will be picked up from the parsed form data
      describe 'sends confirmation email for the 10282' do
        before do
          allow(VANotify::EmailJob).to receive(:perform_async)
        end

        it 'sends the confirmation email' do
          subject = create(:va10282)
          confirmation_number = subject.education_benefits_claim.confirmation_number

          subject.after_submit(user)

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'test@sample.com',
            'form10282_confirmation_email_template_id',
            {
              'first_name' => 'FIRST',
              'benefit' => 'Transfer of Entitlement Program (TOE)',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => confirmation_number,
            },
            Settings.vanotify.services.va_gov.api_key,
            callback_options
          )
        end
      end
    end

    context 'when there is an error with queuing the email' do
      # I don't think we need to test authenticated and unauthenticated users here
      # We're testing the error handling code, not what the queue receives
      let(:user) { nil }

      before do
        allow(VANotify::EmailJob).to receive(:perform_async).and_raise(StandardError, 'Test error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error with the expected message' do
        subject = create(:va10282)

        expected_message =
          'SavedClaim::EducationBenefits::VA10282#send_confirmation_email: ' \
          'Failed to queue confirmation email: Test error'

        expect(Rails.logger).to receive(:error).with(expected_message)
        subject.after_submit(user)
      end
    end
  end
end
