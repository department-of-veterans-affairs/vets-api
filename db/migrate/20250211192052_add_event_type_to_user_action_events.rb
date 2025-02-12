# frozen_string_literal: true

class AddEventTypeToUserActionEvents < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      add_column :user_action_events, :event_id, :string, null: false
      add_column :user_action_events, :event_type, :integer, null: false

      add_index :user_action_events, :event_id, unique: true
      add_index :user_action_events, :event_type
    end
  end
end
