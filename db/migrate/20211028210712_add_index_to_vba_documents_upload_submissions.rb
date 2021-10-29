class AddIndexToVBADocumentsUploadSubmissions < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :vba_documents_upload_submissions, :s3_deleted, algorithm: :concurrently
    add_index :vba_documents_upload_submissions, :created_at, algorithm: :concurrently
  end
end
