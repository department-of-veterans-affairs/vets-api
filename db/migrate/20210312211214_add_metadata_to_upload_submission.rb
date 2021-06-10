class AddMetadataToUploadSubmission < ActiveRecord::Migration[6.0]
  def change
    add_column :vba_documents_upload_submissions, :metadata, :jsonb, default: {}
  end
end
