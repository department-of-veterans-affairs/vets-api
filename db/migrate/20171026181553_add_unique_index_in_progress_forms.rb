class AddUniqueIndexInProgressForms < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    %w(
      index_in_progress_forms_on_form_id
      index_in_progress_forms_on_user_uuid
    ).each do |index|
      remove_index(:in_progress_forms, name: index)
    end

    add_index(:in_progress_forms, [:form_id, :user_uuid], unique: true, algorithm: :concurrently)
  end
end
