# frozen_string_literal: true

class CreateEventBusGatewayPushNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :event_bus_gateway_push_notifications do |t|
      t.references :user_account, null: false, foreign_key: true, type: :uuid
      t.string :template_id, null: false

      t.timestamps
    end
  end
end