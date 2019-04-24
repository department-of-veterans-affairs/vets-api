class CreateNotifications < ActiveRecord::Migration[5.0]
  def change
    create_table :notifications do |t|
      t.integer :account_id, null: false
      t.integer :subject, null: false
      t.integer :status
      t.datetime :status_effective_at
      t.datetime :read_at

      t.timestamps null: false
    end
  end
end
