class ChangeInProgressDataColumn < ActiveRecord::Migration
  def change
    change_column(:in_progress_forms, :encrypted_form_data, :text, null: false)
  end
end
