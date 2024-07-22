class IndexCreatedAtInVerifications < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :vye_verifications, :created_at, algorithm: :concurrently, if_not_exists: true
  end
end
