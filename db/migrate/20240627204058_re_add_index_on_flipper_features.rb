class ReAddIndexOnFlipperFeatures < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    remove_index :flipper_features, column: :key, name: :index_flipper_features_on_key, if_exists: true
    add_index :flipper_features, :key, unique: true, algorithm: :concurrently
  end
end
