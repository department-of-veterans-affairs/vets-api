# frozen_string_literal: true
module Webhooks
  class NotificationAttempt < ApplicationRecord
    self.table_name = 'webhooks_notification_attempts'
    has_many :webhooks_notification_attempt_assocs
    has_many :webhooks_notifications, through: :webhooks_notification_attempt_assocs
  end
end
