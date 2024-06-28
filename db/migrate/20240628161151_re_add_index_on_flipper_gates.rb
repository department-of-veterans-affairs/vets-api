class ReAddIndexOnFlipperGates < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    remove_index :flipper_gates, name: :index_flipper_gates_on_feature_key_and_key_and_value, if_exists: true
    add_index :flipper_gates, [:feature_key, :key, :value], unique: true, algorithm: :concurrently
  end
end
