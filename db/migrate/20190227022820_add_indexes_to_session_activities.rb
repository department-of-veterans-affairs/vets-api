class AddIndexesToSessionActivities < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:session_activities, :originating_request_id, unique: false, algorithm: :concurrently)
    add_index(:session_activities, :user_uuid, unique: false, algorithm: :concurrently)
  end
end
