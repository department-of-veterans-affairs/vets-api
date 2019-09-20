class TestBrokenMigration < ActiveRecord::Migration[5.2]
  def change
    create_table :flipper_features do |t|
      t.string :key, null: false
      t.timestamps null: false
    end
  end
end
