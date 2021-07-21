# frozen_string_literal: true
module Webhooks
  class Notification < ApplicationRecord
    self.table_name = 'webhooks_notifications'
    has_many :webhooks_notification_attempt_assocs
    has_many :webhooks_notification_attempts, through: :webhooks_notification_attempt_assocs
  end
end
