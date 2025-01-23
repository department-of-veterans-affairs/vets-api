class AddUploadSubmissionStatusCreatedAtIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :vba_documents_upload_submissions, [:status, :created_at], name: 'index_vba_docs_upload_submissions_status_created_at_false', where: "s3_deleted IS FALSE", algorithm: :concurrently
  end
end
