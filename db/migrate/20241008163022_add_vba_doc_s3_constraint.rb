class AddVBADocS3Constraint < ActiveRecord::Migration[7.1]
  def up
    add_check_constraint :vba_documents_upload_submissions, 
                         "s3_deleted IS NOT NULL", 
                         name: "vba_documents_upload_submissions_s3_deleted_null", 
                         validate: false
  end
  
  def down
    remove_check_constraint :vba_documents_upload_submissions, 
                            name: "vba_documents_upload_submissions_s3_deleted_null", 
                            if_exists: true
  end
end
