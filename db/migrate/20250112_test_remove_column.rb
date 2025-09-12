class TestRemoveColumn < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :users, :old_field, :string
    end
  end
end