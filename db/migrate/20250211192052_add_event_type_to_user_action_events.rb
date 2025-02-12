# frozen_string_literal: true

class AddEventTypeToUserActionEvents < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    # Remove old slug column if it exists
    if column_exists?(:user_action_events, :slug)
      remove_index :user_action_events, :slug, algorithm: :concurrently if index_exists?(:user_action_events, :slug)
      safety_assured { remove_column :user_action_events, :slug }
    end

    # Add new columns
    add_column :user_action_events, :event_type, :integer, null: false
    add_index :user_action_events, :event_type, 
              algorithm: :concurrently

    add_column :user_action_events, :event_id, :string, null: false
    add_index :user_action_events, :event_id, 
              unique: true, 
              algorithm: :concurrently
  end

  def down
    if column_exists?(:user_action_events, :event_id)
      remove_index :user_action_events, :event_id, algorithm: :concurrently if index_exists?(:user_action_events, :event_id)
      remove_column :user_action_events, :event_id
    end

    if column_exists?(:user_action_events, :event_type)
      remove_index :user_action_events, :event_type, algorithm: :concurrently if index_exists?(:user_action_events, :event_type)
      remove_column :user_action_events, :event_type
    end
  end
end