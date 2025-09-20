class CreateMHVMetricsUniqueUserEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :mhv_metrics_unique_user_events, id: false do |t|
      # Note: user_id intentionally has NO foreign key constraint by design
      # Benefits: Performance optimization for high-volume inserts, historical data preservation
      # even if users are deleted, and operational simplicity for this analytics table
      t.uuid :user_id, null: false, comment: 'Unique user identifier'
      t.string :event_name, limit: 50, null: false, comment: 'Event type name'
      t.timestamp :created_at
    end
  end
end
