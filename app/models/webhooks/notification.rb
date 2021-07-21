# frozen_string_literal: true
module Webhooks
  class Notification < ApplicationRecord
    self.table_name = 'webhooks_notifications'
    has_many :webhooks_notification_attempt_assocs,
             class_name: 'Webhooks::NotificationAttemptAssoc',
             foreign_key: :webhooks_notification_id
    has_many :webhooks_notification_attempts,
             class_name: 'Webhooks::NotificationAttempt',
             through: :webhooks_notification_attempt_assocs
  end
end
