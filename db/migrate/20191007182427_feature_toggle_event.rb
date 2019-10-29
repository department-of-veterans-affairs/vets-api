class FeatureToggleEvent < ActiveRecord::Migration[5.2]
  # fake change
  def change
    create_table(:feature_toggle_events) do |t|
      t.string(:feature_name)
      t.string(:operation)
      t.string(:gate_name)
      t.string(:value)
      t.string(:user)
      t.timestamps(null: false)
      t.index :feature_name
    end
  end
end