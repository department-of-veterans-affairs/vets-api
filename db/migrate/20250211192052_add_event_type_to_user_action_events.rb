# frozen_string_literal: true

class AddEventTypeToUserActionEvents < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # Add event_type column with index
    add_column :user_action_events, :event_type, :integer, null: false
    add_index :user_action_events, :event_type, 
              algorithm: :concurrently

    # Add event_id column with unique constraint
    add_column :user_action_events, :event_id, :string, null: false
    add_index :user_action_events, :event_id, 
              unique: true, 
              algorithm: :concurrently
  end
end
