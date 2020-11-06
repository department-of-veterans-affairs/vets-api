class AddUploadMetadataToVBADocumentsUploadSubmission < ActiveRecord::Migration[6.0]
  def change
    add_column :vba_documents_upload_submissions, :pdf_metadata, :json
  end
end
