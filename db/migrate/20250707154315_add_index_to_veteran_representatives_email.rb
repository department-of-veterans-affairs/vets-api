class AddIndexToVeteranRepresentativesEmail < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute "CREATE INDEX CONCURRENTLY index_veteran_representatives_on_lower_email ON veteran_representatives (LOWER(email))"
    end
  end

  def down
    safety_assured do
      execute "DROP INDEX CONCURRENTLY index_veteran_representatives_on_lower_email"
    end
  end
end
