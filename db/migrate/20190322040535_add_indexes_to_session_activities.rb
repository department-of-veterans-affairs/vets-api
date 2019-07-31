class AddIndexesToSessionActivities < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:session_activities, :name, unique: false, algorithm: :concurrently)
    add_index(:session_activities, :status, unique: false, algorithm: :concurrently)
    add_index(:session_activities, :user_uuid, unique: false, algorithm: :concurrently)
  end
end
