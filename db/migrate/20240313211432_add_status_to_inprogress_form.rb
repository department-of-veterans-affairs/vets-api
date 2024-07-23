class AddStatusToInprogressForm < ActiveRecord::Migration[7.0]
  def change
    add_column :in_progress_forms, :status, :integer
  end
end
