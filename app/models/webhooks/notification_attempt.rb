# frozen_string_literal: true

module Webhooks
  class NotificationAttempt < ApplicationRecord
    self.table_name = 'webhooks_notification_attempts'
    has_many :webhooks_notification_attempt_assocs,
             class_name: 'Webhooks::NotificationAttemptAssoc',
             foreign_key: :webhooks_notification_attempt_id,
             inverse_of: :webhooks_notification_attempt_assocs,
             dependent: :destroy

    has_many :webhooks_notifications,
             class_name: 'Webhooks::Notification',
             through: :webhooks_notification_attempt_assocs
  end
end
