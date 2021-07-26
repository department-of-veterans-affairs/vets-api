class RemovePreferenceTables < ActiveRecord::Migration[6.1]
  def change
    drop_table 'preference_choices'
    drop_table 'preferences'
    drop_table 'user_preferences'
  end
end
