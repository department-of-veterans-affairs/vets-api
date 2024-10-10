class DropVBADocUnusedS3Index < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def change
    remove_index :vba_documents_upload_submissions, 
              [:status, :created_at],
              name: 'index_vba_docs_upload_submissions_status_created_at',
              where: "s3_deleted IS NOT TRUE",
              algorithm: :concurrently,
              if_exists: true
  end
end
