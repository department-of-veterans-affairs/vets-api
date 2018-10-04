class AddExpiresAtToInProgressForms < ActiveRecord::Migration
  def change
    add_column :in_progress_forms, :expires_at, :datetime, null: true
  end
end
