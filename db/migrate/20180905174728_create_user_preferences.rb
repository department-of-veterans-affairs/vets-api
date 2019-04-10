class CreateUserPreferences < ActiveRecord::Migration[4.2]
  def change
    create_table :user_preferences do |t|
      t.integer :account_id,           null: false
      t.integer :preference_id,        null: false
      t.integer :preference_choice_id, null: false

      t.timestamps null: false
    end
  end
end
