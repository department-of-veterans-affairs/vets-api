# frozen_string_literal: true

class EventBusGatewayNotification < ApplicationRecord
  belongs_to :user_account, optional: true

  validates :va_notify_id, presence: true
  validates :template_id, presence: true
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
end
