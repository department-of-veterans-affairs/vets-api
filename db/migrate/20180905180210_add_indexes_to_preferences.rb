class AddIndexesToPreferences < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index(:user_preferences, :account_id,            unique: true,  algorithm: :concurrently)
    add_index(:user_preferences, :preference_id,         unique: true,  algorithm: :concurrently)
    add_index(:user_preferences, :preference_choice_id,  unique: true,  algorithm: :concurrently)
    add_index(:preference_choices, :preference_id,       unique: false, algorithm: :concurrently)
  end
end