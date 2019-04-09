class AddMetadataToInProgressForms < ActiveRecord::Migration[4.2]
  def change
    add_column(:in_progress_forms, :metadata, :json)
  end
end
