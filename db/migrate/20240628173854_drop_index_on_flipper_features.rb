class DropIndexOnFlipperFeatures < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    execute 'DROP INDEX CONCURRENTLY index_flipper_features_on_key;'
  end
end
