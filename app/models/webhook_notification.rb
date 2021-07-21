# frozen_string_literal: true

class WebhookNotification < ApplicationRecord
  has_many :webhook_notification_attempt_assocs
  has_many :webhook_notification_attempts, through: :webhook_notification_attempt_assocs

  def final_attempt
    return nil unless final_attempt_id
    webhook_notification_attempts.select { |a| a.id == final_attempt_id }.first
  end
end
