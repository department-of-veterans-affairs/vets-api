class AddStatusToInprogressFormDefault < ActiveRecord::Migration[7.0]
  def change
    change_column_default :in_progress_forms, :status, from: nil, to: 0
  end
end
