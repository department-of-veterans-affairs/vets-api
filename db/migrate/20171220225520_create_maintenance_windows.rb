class CreateMaintenanceWindows < ActiveRecord::Migration
  def change
    create_table :maintenance_windows do |t|
      t.string :pagerduty_id
      t.string :external_service
      t.datetime :start_time
      t.datetime :end_time
      t.string :description

      t.timestamps null: false
    end
  end
end
