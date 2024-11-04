# frozen_string_literal: true

require 'rails_helper'

describe VANotify::InProgressFormReminderCallback do
  it 'logs status and status_reason' do
    notification_id = SecureRandom.uuid
    notification = create(:notification, notification_id:, status: 'some_status', status_reason: 'some_status_reason',
                                         metadata: 'some_metadata')

    expect(Rails.logger).to receive(:info).with(
      message: "VANotify - in_progress_form_reminder for notification: #{notification.id}",
      status: 'some_status', status_reason: 'some_status_reason', metadata: 'some_metadata'
    )

    described_class.call(notification)
  end
end
