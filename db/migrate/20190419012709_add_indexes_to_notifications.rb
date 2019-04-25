class AddIndexesToNotifications < ActiveRecord::Migration[5.0]
  disable_ddl_transaction!

  def change
    add_index(:notifications, :account_id, unique: false, algorithm: :concurrently)
    add_index(:notifications, :subject, unique: false, algorithm: :concurrently)
    add_index(:notifications, :status, unique: false, algorithm: :concurrently)
  end
end
