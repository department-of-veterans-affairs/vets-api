# frozen_string_literal: true

module Webhooks
  class NotificationAttemptAssoc < ApplicationRecord
    self.table_name = 'webhooks_notification_attempt_assocs'
    belongs_to :webhooks_notification,
               class_name: 'Webhooks::Notification'
    belongs_to :webhooks_notification_attempt,
               class_name: 'Webhooks::NotificationAttempt'
  end
end
