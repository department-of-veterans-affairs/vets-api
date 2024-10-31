# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/callback_class'

describe VANotify::StatusUpdate do
  subject { described_class.new }

  describe '#delegate' do
    context 'notification with callback' do
      it 'invokes callback class #call' do
        notification_id = SecureRandom.uuid
        create(:notification, notification_id:, callback: 'VANotify::OtherTeam::OtherForm')
        allow(VANotify::OtherTeam::OtherForm).to receive(:call)

        provider_callback = {
          id: notification_id
        }

        subject.delegate(provider_callback)

        expect(VANotify::OtherTeam::OtherForm).to have_received(:call)
      end

      it 'logs error message if #call fails' do
        notification_id = SecureRandom.uuid
        notification = create(:notification, notification_id:, callback: 'VANotify::OtherTeam::OtherForm')
        provider_callback = {
          id: notification_id
        }

        allow(notification.callback.constantize).to receive(:call).with(notification).and_raise(StandardError,
                                                                                                'Something went wrong')

        expect(Rails.logger).to receive(:info).with('Something went wrong')

        subject.delegate(provider_callback)
      end

      it 'logs a message and source location if callback klass does not implement #call' do
        notification_id = SecureRandom.uuid
        notification = create(:notification, notification_id:,
                                             callback: 'VANotify::NonCompliantModule::NonCompliantClass')
        provider_callback = {
          id: notification_id
        }

        expect(Rails.logger).to receive(:info).with(message: 'The callback class does not implement #call')
        expect(Rails.logger).to receive(:info).with(source: notification.source_location)

        subject.delegate(provider_callback)
      end
    end

    context 'notification without callback' do
      it 'logs the status' do
        notification_id = SecureRandom.uuid
        notification = create(:notification, notification_id:)

        provider_callback = {
          id: notification_id,
        }

        expected_error_message = "VANotify - no callback provided for notification: #{notification.id}"

        expect(Rails.logger).to receive(:info).with(message: expected_error_message)

        subject.delegate(provider_callback)
      end
    end
  end
end
