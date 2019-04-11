class AddExpiresAtToInProgressForms < ActiveRecord::Migration[4.2]
  def change
    add_column :in_progress_forms, :expires_at, :datetime, null: true
  end
end
