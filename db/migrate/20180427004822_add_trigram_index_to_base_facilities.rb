class AddTrigramIndexToBaseFacilities < ActiveRecord::Migration
  # An index can be created concurrently only outside of a transaction.
  disable_ddl_transaction!
  safety_assured

  def up
    execute <<-SQL
      CREATE INDEX CONCURRENTLY index_base_facilities_on_name ON base_facilities USING gin(name gin_trgm_ops);
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX index_base_facilities_on_name;
    SQL
  end
end
