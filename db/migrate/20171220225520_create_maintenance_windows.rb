class CreateMaintenanceWindows < ActiveRecord::Migration[4.2]
  def change
    create_table :maintenance_windows do |t|
      t.string :pagerduty_id
      t.string :external_service
      t.datetime :start_time
      t.datetime :end_time
      t.string :description

      t.timestamps null: false

      t.index :pagerduty_id
      t.index :start_time
      t.index :end_time
    end
  end
end
