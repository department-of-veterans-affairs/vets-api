class ModVBADocIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    validate_check_constraint :vba_documents_upload_submissions, 
                              name: "vba_documents_upload_submissions_s3_deleted_null"
    change_column_null :vba_documents_upload_submissions, 
                       :s3_deleted, 
                       false
    remove_check_constraint :vba_documents_upload_submissions, 
                            name: "vba_documents_upload_submissions_s3_deleted_null", 
                            if_exists: true
  
    change_column_default :vba_documents_upload_submissions,  
                          :s3_deleted, 
                          from: nil, 
                          to: false  
    remove_index :vba_documents_upload_submissions, 
                 name: 'index_vba_docs_upload_submissions_status_created_at',
                 algorithm: :concurrently,
                 if_exists: true

  end

  def down
    change_column_null :vba_documents_upload_submissions, :s3_deleted, true
    change_column_default :vba_documents_upload_submissions, :s3_deleted, from: false, to: nil
    add_index :vba_documents_upload_submissions, 
              [:status, :created_at],
              name: 'index_vba_docs_upload_submissions_status_created_at',
              where: "s3_deleted IS NOT TRUE",
              algorithm: :concurrently,
              if_not_exists: true
    add_check_constraint :vba_documents_upload_submissions, 
                         "s3_deleted IS NOT NULL", 
                         name: "vba_documents_upload_submissions_s3_deleted_null", 
                         validate: false,
                         if_not_exists: true

  end

end
