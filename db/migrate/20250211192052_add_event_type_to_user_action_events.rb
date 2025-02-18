# frozen_string_literal: true

class AddEventTypeToUserActionEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :user_action_events, :event_id, :string
    add_column :user_action_events, :event_type, :integer
  end
end
