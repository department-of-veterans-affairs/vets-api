class AddTudAccounts < ActiveRecord::Migration[6.0]
  def change
    create_table :test_user_dashboard_tud_accounts do |t|
      t.belongs_to :account, foreign_key: :uuid, required: true
      t.boolean :standard, :available
      t.datetime :checkout_time
      t.timestamps
    end
  end
end