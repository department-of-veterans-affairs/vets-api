# frozen_string_literal: true
class WebhookNotificationAttempt < ApplicationRecord
  has_many :webhook_notification_attempt_assocs
  has_many :webhook_notifications, through: :webhook_notification_attempt_assocs
end
