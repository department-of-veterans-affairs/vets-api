class AddMetadataToInProgressForms < ActiveRecord::Migration
  def change
    add_column(:in_progress_forms, :metadata, :json)
  end
end
