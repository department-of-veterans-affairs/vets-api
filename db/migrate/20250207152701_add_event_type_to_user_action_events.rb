class AddEventTypeToUserActionEvents < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :user_action_events, :event_type, :integer
    add_column :user_action_events, :slug, :string

    add_index :user_action_events, :event_type, algorithm: :concurrently
    add_index :user_action_events, :slug, algorithm: :concurrently
  end
end 