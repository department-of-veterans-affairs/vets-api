class RemoveUserPreferenceChoiceIndex < ActiveRecord::Migration
  def change
    remove_index(:user_preferences, :preference_choice_id)
  end
end
