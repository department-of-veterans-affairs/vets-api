class RemoveInProgressFormsIndexes < ActiveRecord::Migration
  def change
    %w(
      index_in_progress_forms_on_form_id
      index_in_progress_forms_on_user_uuid
    ).each do |index|
      remove_index(:in_progress_forms, name: index)
    end
  end
end
