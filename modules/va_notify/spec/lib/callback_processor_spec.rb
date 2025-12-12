# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/callback_processor'

RSpec.describe VANotify::CallbackProcessor do
  describe '#call' do
    subject(:callback_processor) { described_class.new(notification, notification_params) }

    let(:notification) { create(:notification) }
    let(:notification_params) do
      {
        status: 'delivered',
        status_reason: 'Test reason',
        completed_at: Time.zone.now.iso8601
      }
    end

    it 'updates the notification with the given params' do
      callback_processor.call

      notification.reload
      expect(notification.status).to eq('delivered')
      expect(notification.status_reason).to eq('Test reason')
    end

    it 'logs the notification update' do
      allow(Rails.logger).to receive(:info)

      callback_processor.call

      expect(Rails.logger).to have_received(:info).with(
        "va_notify callback_processor - Updated notification: #{notification.id}",
        hash_including(
          notification_id: notification.id,
          status: 'delivered',
          status_reason: 'Test reason'
        )
      )
    end

    it 'delegates to DefaultCallback with the notification' do
      default_callback = instance_double(VANotify::DefaultCallback, call: true)
      allow(VANotify::DefaultCallback).to receive(:new).with(notification).and_return(default_callback)

      callback_processor.call

      expect(VANotify::DefaultCallback).to have_received(:new).with(notification)
      expect(default_callback).to have_received(:call)
    end

    it 'delegates to CustomCallback with notification params including id' do
      custom_callback = instance_double(VANotify::CustomCallback, call: true)
      allow(VANotify::CustomCallback).to receive(:new).and_return(custom_callback)

      callback_processor.call

      expect(VANotify::CustomCallback).to have_received(:new).with(
        hash_including(id: notification.notification_id)
      )
      expect(custom_callback).to have_received(:call)
    end
  end
end
