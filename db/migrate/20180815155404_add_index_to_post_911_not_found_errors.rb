class AddIndexToPost911NotFoundErrors < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:post911_not_found_errors, :user_uuid, unique: true, algorithm: :concurrently)
  end
end
