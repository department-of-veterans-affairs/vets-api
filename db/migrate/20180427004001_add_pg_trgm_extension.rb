class AddPgTrgmExtension < ActiveRecord::Migration[4.2]
  def up
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
    execute "CREATE EXTENSION IF NOT EXISTS btree_gin;"
  end

  def down
    execute "DROP EXTENSION IF EXISTS pg_trgm;"
    execute "DROP EXTENSION IF EXISTS btree_gin;"
  end
end
