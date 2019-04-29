class AddUniqueIndexCombinationOnNotifications < ActiveRecord::Migration[5.0]
  disable_ddl_transaction!

  def change
    add_index(:notifications, [:account_id, :subject], unique: true, algorithm: :concurrently)
  end
end
