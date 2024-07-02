class AddOptimizedIndexToVBADocumentsUploadSubmissions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_index :vba_documents_upload_submissions, 
                [:status, :created_at],
                name: 'index_vba_docs_upload_submissions_status_created_at',
                where: "s3_deleted IS NOT TRUE",
                algorithm: :concurrently
    end
  end
end