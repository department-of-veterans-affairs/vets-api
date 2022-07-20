class DropAppealsApiEventSubscriptions < ActiveRecord::Migration[6.1]
  def change
    drop_table :appeals_api_event_subscriptions
  end
end
