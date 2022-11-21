class DropSessionActivities < ActiveRecord::Migration[6.1]
  def up
    drop_table :session_activities
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
