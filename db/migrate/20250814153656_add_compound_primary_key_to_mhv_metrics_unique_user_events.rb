class AddCompoundPrimaryKeyToMHVMetricsUniqueUserEvents < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # Add unique compound index - columns already have NOT NULL constraints from table creation
    # This ensures one record per user per event type
    add_index :mhv_metrics_unique_user_events, 
              [:user_id, :event_name], 
              unique: true,
              algorithm: :concurrently,
              name: 'index_mhv_metrics_unique_user_events_on_user_id_and_event_name'
  end
end
