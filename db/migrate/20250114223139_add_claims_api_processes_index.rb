class AddClaimsApiProcessesIndex < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :claims_api_processes, [:processable_id, :processable_type], algorithm: :concurrently
  end
end
