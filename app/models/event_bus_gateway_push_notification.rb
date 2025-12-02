# frozen_string_literal: true

class EventBusGatewayPushNotification < ApplicationRecord
  belongs_to :user_account

  validates :template_id, presence: true
end
