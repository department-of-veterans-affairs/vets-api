class AddUuidIndexToAccount < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:accounts, :uuid, unique: true, algorithm: :concurrently)
  end
end
