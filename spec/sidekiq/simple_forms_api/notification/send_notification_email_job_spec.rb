# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::Notification::SendNotificationEmailJob, type: :worker do
  let(:notification_email) { instance_double(SimpleFormsApi::NotificationEmail, send: nil) }
  let(:form_upload_notification_email) { instance_double(SimpleFormsApi::FormUploadNotificationEmail, send: nil) }
  let(:notification_type) { :confirmation }
  let(:form_submission_attempt) { create(:form_submission_attempt) }
  let(:form_number) { '21-0779' }
  let(:user_account) { create(:user_account) }
  let(:args) do
    {
      notification_type:,
      form_submission_attempt_id: form_submission_attempt.id,
      form_number:,
      user_account_id: user_account.id
    }
  end

  before do
    allow(UserAccount).to receive(:find).with(user_account.id).and_return(user_account)
    allow(FormSubmissionAttempt).to receive(:find).with(form_submission_attempt.id).and_return(form_submission_attempt)
    allow(SimpleFormsApi::NotificationEmail).to receive(:new).and_return(notification_email)
    allow(SimpleFormsApi::FormUploadNotificationEmail).to receive(:new).and_return(form_upload_notification_email)
    allow(StatsD).to receive(:increment)
  end

  describe '#perform' do
    subject(:perform) { described_class.new.perform(args) }

    context 'when the form is submitted using the digital form submission tool' do
      before { perform }

      it 'sends a notification email' do
        expect(notification_email).to have_received(:send).with(at: anything)
      end
    end

    context 'when the form is submitted with the Form Upload tool' do
      before do
        allow(SimpleFormsApi::FormUploadNotificationEmail).to receive(:SUPPORTED_FORMS).and_return([form_number])
        perform
      end

      it 'sends a form upload notification email' do
        expect(form_upload_notification_email).to have_received(:send).with(at: anything)
      end
    end

    context 'when an error occurs during email sending' do
      let(:error_message) { 'Test error' }

      before do
        allow(notification_email).to receive(:send).and_raise(StandardError, error_message)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs an error' do
        expect { perform }.to raise_error(StandardError, error_message)
        expect(Rails.logger).to have_received(:error).with(
          hash_including(message: error_message)
        )
      end

      it 'increments StatsD for silent failures' do
        expect { perform }.to raise_error(StandardError)
        expect(StatsD).to have_received(:increment).with('silent_failure', tags: anything)
      end
    end

    context 'when required arguments are missing' do
      let(:args) { {} }

      it 'raises an ArgumentError' do
        expect { perform }.to raise_error(ArgumentError, /Expected a Hash, got/)
      end
    end
  end

  describe '#perform_async' do
    it 'enqueues the job' do
      expect { described_class.perform_async(args) }.to change(described_class.jobs, :size).by(1)
    end
  end
end
