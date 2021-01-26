class AddTudAccounts < ActiveRecord::Migration[6.0]
  def change
    create_table :test_user_dashboard_tud_accounts do |t|
      t.string :account_uuid, :first_name, :middle_name, :last_name, :gender
      t.datetime :birth_date
      t.integer :ssn
      t.string :phone, :email, :password
      t.boolean :standard, :available
      t.datetime :checkout_time
      t.timestamps
    end
  end
end
