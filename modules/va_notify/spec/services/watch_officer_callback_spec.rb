# frozen_string_literal: true

require 'rails_helper'

describe VANotify::WatchOfficerCallback do
  describe '.call' do
    it 'delivered' do
      notification_id = SecureRandom.uuid
      notification = create(:notification, notification_id:, status: 'delivered')

      allow(StatsD).to receive(:increment).with('api.vanotify.notifications.delivered')

      described_class.call(notification)

      expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.delivered')
    end

    it 'permanent-failure' do
      notification_id = SecureRandom.uuid
      notification = create(:notification, notification_id:, status: 'permanent-failure',
                                           status_reason: 'some_status_reason', source_location: 'some/file/path/here')

      allow(StatsD).to receive(:increment).with('api.vanotify.notifications.permanent_failure')

      expect(Rails.logger).to receive(:error).with(notification_id:, source: 'some/file/path/here',
                                                   status: 'permanent-failure', status_reason: 'some_status_reason')

      described_class.call(notification)
      expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.permanent_failure')
    end

    it 'other' do
      notification_id = SecureRandom.uuid
      notification = create(:notification, notification_id:, status: 'other', status_reason: 'some_status_reason',
                                           source_location: 'some/file/path/here')

      allow(StatsD).to receive(:increment).with('api.vanotify.notifications.other')

      expect(Rails.logger).to receive(:error).with(notification_id:, source: 'some/file/path/here', status: 'other',
                                                   status_reason: 'some_status_reason')

      described_class.call(notification)
      expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.other')
    end
  end
end
