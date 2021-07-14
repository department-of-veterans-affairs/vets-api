# frozen_string_literal: true
class WebhookNotificationAttemptAssoc < ApplicationRecord
  belongs_to :webhook_notification
  belongs_to :webhook_notification_attempt
end
