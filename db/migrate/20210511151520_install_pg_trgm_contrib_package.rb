class InstallPgTrgmContribPackage < ActiveRecord::Migration[6.0]
  def change
    safety_assured { execute "DROP EXTENSION pg_trgm;" }
    safety_assured { execute "CREATE EXTENSION pg_trgm;" }
  end
end
