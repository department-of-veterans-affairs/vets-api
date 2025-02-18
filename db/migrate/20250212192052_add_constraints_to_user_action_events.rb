# frozen_string_literal: true

class AddConstraintsToUserActionEvents < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      # Add indexes
      add_index :user_action_events, :event_id, unique: true
      add_index :user_action_events, :event_type

      # Add NOT NULL constraints
      change_column_null :user_action_events, :event_id, false
      change_column_null :user_action_events, :event_type, false
    end
  end
end
