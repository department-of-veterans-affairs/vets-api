class CreateVbaDocumentsUploadSubmissions < ActiveRecord::Migration
  def change
    create_table :vba_documents_upload_submissions do |t|
      t.string("status", default: "pending", index: true, null: false)
      t.uuid("guid", index: true, null: false)
      t.timestamps(null: false)
    end
  end
end
