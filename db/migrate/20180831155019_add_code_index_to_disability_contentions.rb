class AddCodeIndexToDisabilityContentions < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:disability_contentions, :code, unique: true, algorithm: :concurrently)
  end
end
