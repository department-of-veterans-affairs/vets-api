class AddFlipperIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    if ActiveRecord::Base.connection.execute("SELECT * FROM pg_indexes WHERE indexname = 'index_flipper_features_on_key';").count == 0
      add_index :flipper_features, :key, unique: true, algorithm: :concurrently
    end
    if ActiveRecord::Base.connection.execute("SELECT * FROM pg_indexes WHERE indexname = 'index_flipper_gates_on_feature_key_and_key_and_value';").count == 0
      add_index :flipper_gates, [:feature_key, :key, :value], unique: true, algorithm: :concurrently
    end
  end
end
