# frozen_string_literal: true

class AddS3DeletedToUploadSubmissions < ActiveRecord::Migration
  def change
    add_column :vba_documents_upload_submissions, :s3_deleted, :boolean
  end
end
