class AddEventSubscriptions < ActiveRecord::Migration[6.0]
  def change
    create_table :appeals_api_event_subscriptions do |t|
      t.string :topic
      t.string :callback

      t.index [:topic, :callback]

      t.timestamps
    end
  end
end
