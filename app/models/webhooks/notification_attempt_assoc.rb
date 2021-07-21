# frozen_string_literal: true
module Webhooks
  class NotificationAttemptAssoc < ApplicationRecord
    self.table_name = 'webhooks_notification_attempt_assocs'
    belongs_to :webhooks_notification
    belongs_to :webhooks_notification_attempt
  end
end