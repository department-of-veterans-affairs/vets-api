class RemoveUserPreferenceIndexes < ActiveRecord::Migration[4.2]
  def change
    remove_index(:user_preferences, :account_id)
    remove_index(:user_preferences, :preference_id)
  end
end
