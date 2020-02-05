class AddIndexToInProgressForms < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_index :in_progress_forms, :user_uuid, algorithm: :concurrently
  end
end
