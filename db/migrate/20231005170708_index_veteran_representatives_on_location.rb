class IndexVeteranRepresentativesOnLocation < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :veteran_representatives, :location, using: :gist, algorithm: :concurrently
  end
end
