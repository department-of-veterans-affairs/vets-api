class DropUploadSubmissionStatusCreatedAtIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    remove_index "vba_documents_upload_submissions", column: [:status, :created_at], name: "index_vba_docs_upload_submissions_status_created_at", where: "s3_deleted IS NOT TRUE", if_exists: true
  end
end
