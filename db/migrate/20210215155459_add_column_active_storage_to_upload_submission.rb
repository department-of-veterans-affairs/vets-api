class AddColumnActiveStorageToUploadSubmission < ActiveRecord::Migration[6.0]
  def change
    add_column :vba_documents_upload_submissions, :use_active_storage, :boolean, default: false
  end
end
