# frozen_string_literal: true

class AddEventTypeToUserActionEvents < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # Add event_type column with index
    add_column :user_action_events, :event_type, :integer, null: false
    add_index :user_action_events, :event_type, 
              algorithm: :concurrently

    # Add slug column with unique constraint
    add_column :user_action_events, :slug, :string, null: false  # Added null: false here
    add_index :user_action_events, :slug, 
              unique: true, 
              algorithm: :concurrently
  end
end
