# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::Notification::SendNotificationEmailJob, type: :worker do
  describe '#perform' do
    context 'form was submitted with a digital form submission tool' do
      it 'sends the email' do
        notification_type = :confirmation
        form_submission_attempt = build(:form_submission_attempt)
        user_account = build(:user_account)
        notification_email = double(send: nil)
        allow(SimpleFormsApi::NotificationEmail).to receive(:new).and_return(notification_email)

        SimpleFormsApi::Notification::SendNotificationEmailJob.new.perform(
          notification_type:,
          form_submission_attempt:,
          user_account:
        )

        expect(notification_email).to have_received(:send).with(at: anything)
      end
    end
  end
end
