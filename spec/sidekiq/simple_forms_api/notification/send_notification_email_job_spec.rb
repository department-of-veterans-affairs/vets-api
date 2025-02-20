# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::Notification::SendNotificationEmailJob, type: :worker do
  describe '#perform' do
    context 'form was submitted with a digital form submission tool' do
      let(:notification_type) { :confirmation }
      let(:form_submission_attempt) { build(:form_submission_attempt) }
      let(:form_number) { 'abc-123' }
      let(:user_account) { build(:user_account) }
      let(:notification_email) { double(send: nil) }

      it 'sends the email' do
        allow(SimpleFormsApi::NotificationEmail).to receive(:new).and_return(notification_email)

        described_class.new.perform(
          notification_type:,
          form_submission_attempt:,
          form_number:,
          user_account:
        )

        expect(notification_email).to have_received(:send).with(at: anything)
      end

      context 'SimpleFormsApi::NotificationEmail initialization fails' do
        it 'raises an error and increments statsd' do
          allow(SimpleFormsApi::NotificationEmail).to receive(:new).and_raise(ArgumentError)
          allow(StatsD).to receive(:increment)

          expect do
            described_class.new.perform(
              notification_type: :error,
              form_submission_attempt:,
              form_number:,
              user_account:
            )
          end.to raise_error(ArgumentError)
          expect(StatsD).to have_received(:increment).with('silent_failure', tags: anything)
        end
      end
    end

    context 'form was submitted with Form Upload tool' do
      let(:notification_type) { :confirmation }
      let(:form_submission_attempt) { build(:form_submission_attempt, :form_upload) }
      let(:form_number) { '21-0779' }
      let(:user_account) { build(:user_account) }
      let(:form_upload_notification_email) { double(send: nil) }

      it 'sends the email' do
        allow(SimpleFormsApi::FormUploadNotificationEmail).to receive(:new).and_return(form_upload_notification_email)

        described_class.new.perform(
          notification_type:,
          form_submission_attempt:,
          form_number:,
          user_account:
        )

        expect(form_upload_notification_email).to have_received(:send).with(at: anything)
      end

      context 'SimpleFormsApi::FormUploadNotificationEmail initialization fails' do
        it 'raises an error and increments statsd' do
          allow(SimpleFormsApi::FormUploadNotificationEmail).to receive(:new).and_raise(ArgumentError)
          allow(StatsD).to receive(:increment)

          expect do
            described_class.new.perform(
              notification_type: :error,
              form_submission_attempt:,
              form_number:,
              user_account:
            )
          end.to raise_error(ArgumentError)
          expect(StatsD).to have_received(:increment).with('silent_failure', tags: anything)
        end
      end
    end
  end
end
