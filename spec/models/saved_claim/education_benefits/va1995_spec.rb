# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA1995 do
  let(:instance) { build(:va1995) }
  let(:callback_options) {
    {
      callback_metadata: {
        notification_type: 'confirmation',
        form_number: '22-1995',
        statsd_tags: { service: 'submit-1995-form', function: 'form_1995_failure_confirmation_email_sending' }
      }
    }
  }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-1995')

  describe '#after_submit' do
    before do
      allow(Flipper).to receive(:enabled?).and_call_original
      allow(Flipper).to receive(:enabled?).with(:form1995_confirmation_email).and_return(true)
    end

    context 'authenticated user (logged in)' do
      # email will be picked up from the user profile of the logged in user
      let(:user) { create(:user) }

      describe 'sends confirmation email for the 1995' do
        before do
          allow(VANotify::EmailJob).to receive(:perform_async)
        end

        it 'with benefit selected' do
          subject = create(:va1995_full_form)
          confirmation_number = subject.education_benefits_claim.confirmation_number

          subject.after_submit(user)

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            user.email,
            'form1995_confirmation_email_template_id',
            {
              'first_name' => 'FIRST',
              'benefit' => 'Transfer of Entitlement Program (TOE)',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => confirmation_number,
              'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
            },
            callback_options
          )
        end

        it 'without benefit selected' do
          subject = create(:va1995_full_form)
          parsed_form_data = JSON.parse(subject.form)
          parsed_form_data.delete('benefit')
          subject.form = parsed_form_data.to_json
          confirmation_number = subject.education_benefits_claim.confirmation_number

          subject.after_submit(user)

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            user.email,
            'form1995_confirmation_email_template_id',
            {
              'first_name' => 'FIRST',
              'benefit' => '',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => confirmation_number,
              'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
            },
            callback_options
          )
        end
      end
    end

    context 'unauthenticated user (not logged in)' do
      let(:user) { nil }

      # email will be picked up from the parsed form data
      describe 'sends confirmation email for the 1995' do
        before do
          allow(VANotify::EmailJob).to receive(:perform_async)
        end

        it 'with benefit selected' do
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
            callback_options
          )
        end

        it 'without benefit selected' do
          subject = create(:va1995_full_form)
          parsed_form_data = JSON.parse(subject.form)
          parsed_form_data.delete('benefit')
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
