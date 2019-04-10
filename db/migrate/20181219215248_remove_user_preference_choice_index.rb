class RemoveUserPreferenceChoiceIndex < ActiveRecord::Migration[4.2]
  def change
    remove_index(:user_preferences, :preference_choice_id)
  end
end
