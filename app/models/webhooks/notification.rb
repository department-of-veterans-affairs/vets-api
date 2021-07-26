# frozen_string_literal: true

module Webhooks
  class Notification < ApplicationRecord
    self.table_name = 'webhooks_notifications'
    has_many :webhooks_notification_attempt_assocs,
             class_name: 'Webhooks::NotificationAttemptAssoc',
             foreign_key: :webhooks_notification_id,
             inverse_of: :webhooks_notification_attempt_assocs,
             dependent: :destroy

    has_many :webhooks_notification_attempts,
             class_name: 'Webhooks::NotificationAttempt',
             through: :webhooks_notification_attempt_assocs

    def final_attempt
      return nil unless final_attempt_id

      webhooks_notification_attempts.select { |a| a.id == final_attempt_id }.first
    end
  end
end
