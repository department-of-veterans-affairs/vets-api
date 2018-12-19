class AddNonUniquePreferenceChoiceIndex < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:user_preferences, :preference_choice_id, unique: false,  algorithm: :concurrently)
  end
end
