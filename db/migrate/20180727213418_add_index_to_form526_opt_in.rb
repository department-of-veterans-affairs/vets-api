class AddIndexToForm526OptIn < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:form526_opt_ins, :user_uuid, unique: true, algorithm: :concurrently)
  end
end
