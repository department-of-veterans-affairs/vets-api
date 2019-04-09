class AddBackUserPreferenceIndexes < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index(:user_preferences, :account_id, unique: false,  algorithm: :concurrently)
    add_index(:user_preferences, :preference_id, unique: false,  algorithm: :concurrently)
  end
end
