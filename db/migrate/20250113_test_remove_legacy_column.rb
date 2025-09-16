class TestRemoveLegacyColumn < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :users, :legacy_field, :string
    end
  end
end