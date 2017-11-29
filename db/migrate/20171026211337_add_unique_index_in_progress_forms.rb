class AddUniqueIndexInProgressForms < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:in_progress_forms, [:form_id, :user_uuid], unique: true, algorithm: :concurrently)
  end
end
