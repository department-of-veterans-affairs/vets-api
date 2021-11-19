class CreateTudAccountsAvailabilityLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :test_user_dashboard_tud_account_availability_logs do |t|
      t.string :account_uuid
      t.timestamp :checkout_time
      t.timestamp :checkin_time, null: true
      t.boolean :has_checkin_error, :is_manual_checkin, null: true
      t.timestamps
    end

    add_index :test_user_dashboard_tud_account_availability_logs, :account_uuid, name: 'tud_account_availability_logs'
  end
end
