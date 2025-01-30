# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::Notification::SendNotificationEmailJob, type: :worker do
  describe '#perform' do
    context 'form was submitted with a digital form submission tool' do
      let(:notification_type) { :confirmation }
      let(:form_submission_attempt) { build(:form_submission_attempt) }
      let(:user_account) { build(:user_account) }
      let(:notification_email) { double(send: nil) }

      it 'sends the email' do
        allow(SimpleFormsApi::NotificationEmail).to receive(:new).and_return(notification_email)

        described_class.new.perform(
          notification_type:,
          form_submission_attempt:,
          user_account:
        )

        expect(notification_email).to have_received(:send).with(at: anything)
      end

      context 'SimpleFormsApi::NotificationEmail initialization fails' do
        it 'raises an error' do
          allow(SimpleFormsApi::NotificationEmail).to receive(:new).and_raise(ArgumentError)

          expect do
            described_class.new.perform(
              notification_type:,
              form_submission_attempt:,
              user_account:
            )
          end.to raise_error(ArgumentError)
        end
      end
    end
  end
end
