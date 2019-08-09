# frozen_string_literal: true

class AddConsumerIdToUploadSubmission < ActiveRecord::Migration[4.2]
  def change
    add_column :vba_documents_upload_submissions, :consumer_id, :uuid
  end
end
