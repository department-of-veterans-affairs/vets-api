# frozen_string_literal: true

class AddConsumerNameToVBADocumentsUploadSubmissions < ActiveRecord::Migration
  def change
    add_column :vba_documents_upload_submissions, :consumer_name, :string
  end
end
