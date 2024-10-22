# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/callback_class'

describe VANotify::StatusUpdate do
  describe '#delegate' do
    context 'notification with callback' do
      it 'returns the callback klass' do
        notification_id = SecureRandom.uuid
        create(:notification, notification_id:, callback: 'OtherTeam::OtherForm')

        provider_callback = {
          id: notification_id
        }

        received_callback = described_class.new.delegate(provider_callback)

        expect(received_callback).to be_truthy
      end

      it 'logs error message if callback klass throws error during #call' do
        notification_id = SecureRandom.uuid
        notification = create(:notification, notification_id:, callback: 'OtherTeam::OtherForm')
        provider_callback = {
          id: notification_id
        }

        allow(notification.callback.constantize).to receive(:call).with(notification).and_raise(StandardError,
                                                                                                'Something went wrong')

        expect(Rails.logger).to receive(:info).with('Something went wrong')

        described_class.new.delegate(provider_callback)
      end

      it 'logs a message and source location if callback klass does not implement #call' do
        notification_id = SecureRandom.uuid
        notification = create(:notification, notification_id:, callback: 'NonCompliantModule::NonCompliantClass')
        provider_callback = {
          id: notification_id
        }

        expect(Rails.logger).to receive(:info).with(message: 'The callback class does not implement #call')
        expect(Rails.logger).to receive(:info).with(source: notification.source_location)

        described_class.new.delegate(provider_callback)
      end
    end

    context 'notification without callback' do
      it 'logs the status' do
        notification_id = SecureRandom.uuid
        notification = create(:notification, notification_id:, callback: nil)

        provider_callback = {
          id: notification_id,
          status: 'temporary-failure'
        }

        expected_error_message = "undefined method `constantize' for nil"

        expect(Rails.logger).to receive(:info).with(source: notification.source_location, status: notification.status,
                                                    error_message: expected_error_message)

        described_class.new.delegate(provider_callback)
      end
    end
  end
end
