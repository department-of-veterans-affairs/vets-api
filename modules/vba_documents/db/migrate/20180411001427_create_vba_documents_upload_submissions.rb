# frozen_string_literal: true

class CreateVBADocumentsUploadSubmissions < ActiveRecord::Migration
  def change
    create_table :vba_documents_upload_submissions do |t|
      t.uuid('guid', index: true, null: false)
      t.string('status', default: 'pending', index: true, null: false)
      t.string('code')
      t.string('detail')
      t.timestamps(null: false)
    end
  end
end
