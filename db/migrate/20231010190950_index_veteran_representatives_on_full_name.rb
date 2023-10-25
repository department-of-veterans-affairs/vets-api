class IndexVeteranRepresentativesOnFullName < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :veteran_representatives, :full_name, algorithm: :concurrently
  end
end
