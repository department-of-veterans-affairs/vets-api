class UserActionEventNotNull < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :user_action_events, "event_id IS NOT NULL", name: "user_action_events_event_id_null", validate: false
    add_check_constraint :user_action_events, "event_type IS NOT NULL", name: "user_action_events_event_type_null", validate: false
  end
end
