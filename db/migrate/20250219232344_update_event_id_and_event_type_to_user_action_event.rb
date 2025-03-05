class UpdateEventIdAndEventTypeToUserActionEvent < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :user_action_events, :event_type, :integer
      add_column :user_action_events, :event_type, :string, null: false
      remove_column :user_action_events, :event_id, :string
      add_column :user_action_events, :identifier, :string, null: false

      add_index :user_action_events, :identifier, unique: true
    end
  end
end
