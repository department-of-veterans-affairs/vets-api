class RemoveUserPreferenceIndexes < ActiveRecord::Migration
  def change
    remove_index(:user_preferences, :account_id)
    remove_index(:user_preferences, :preference_id)
  end
end
