class AddFlipperIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :flipper_features, :key, unique: true, algorithm: :concurrently
    add_index :flipper_gates, [:feature_key, :key, :value], unique: true, algorithm: :concurrently
  end
end
