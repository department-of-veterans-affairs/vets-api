# frozen_string_literal: true

class WebhookNotification < ApplicationRecord
  has_many :webhook_notification_attempt_assocs
  has_many :webhook_notification_attempts, through: :webhook_notification_attempt_assocs
end
