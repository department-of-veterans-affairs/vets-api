class AddCodeIndexToDisabilityContentions < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index(:disability_contentions, :code, unique: true, algorithm: :concurrently)
  end
end
