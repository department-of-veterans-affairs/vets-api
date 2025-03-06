# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::Notification::SendNotificationEmailJob, type: :worker do
  let(:notification_email) { double(send: nil) }
  let(:form_upload_notification_email) { double(send: nil) }
  let(:notification_type) { :confirmation }
  let(:form_submission_attempt) { build(:form_submission_attempt) }
  let(:form_number) { '21-0779' }
  let(:user_account) { build(:user_account) }
  let(:args) do
    {
      notification_type:,
      form_submission_attempt_id: form_submission_attempt.id,
      form_number:,
      user_account_id: user_account.id
    }
  end

  before do
    allow(UserAccount).to receive(:find).and_return(user_account)
    allow(FormSubmissionAttempt).to receive(:find).and_return(form_submission_attempt)
    allow(SimpleFormsApi::NotificationEmail).to receive(:new).and_return(notification_email)
    allow(SimpleFormsApi::FormUploadNotificationEmail).to receive(:new).and_return(form_upload_notification_email)
    allow(StatsD).to receive(:increment)
  end

  describe '#perform' do
    subject(:perform) { described_class.new.perform(args) }

    before { perform }

    context 'form was submitted with a digital form submission tool' do
      it 'sends the email' do
        expect(notification_email).to have_received(:send).with(at: anything)
      end

      context 'SimpleFormsApi::NotificationEmail initialization fails' do
        it 'increments statsd' do
          expect(StatsD).to have_received(:increment).with('silent_failure', tags: anything)
        end
      end
    end

    context 'form was submitted with Form Upload tool' do
      it 'sends the email' do
        expect(form_upload_notification_email).to have_received(:send).with(at: anything)
      end

      context 'SimpleFormsApi::FormUploadNotificationEmail initialization fails' do
        before do
          allow(SimpleFormsApi::FormUploadNotificationEmail).to receive(:new).and_raise(ArgumentError)
        end

        it 'increments statsd' do
          expect(StatsD).to have_received(:increment).with('silent_failure', tags: anything)
        end
      end
    end
  end

  describe '#perform_async' do
    subject(:perform_async) { described_class.perform_async(args) }

    before do
      perform_async
    end

    it 'enqueues the job' do
      expect(described_class).to respond_to(:perform_async)
    end

    it 'finds the user account' do
      expect(UserAccount).to have_received(:find).with(user_account.id)
    end

    it 'finds the form submission attempt' do
      expect(FormSubmissionAttempt).to have_received(:find).with(form_submission_attempt.id)
    end

    it 'initializes the notification email' do
      expect(SimpleFormsApi::NotificationEmail).to have_received(:new)
    end
  end
end
