class AddDocumentUpload < ActiveRecord::Migration
  def change
    create_table "document_upload_submissions" do |t|
      t.string("status", default: "pending", index: true, null: false)
      t.uuid("guid", index: true, null: false)
    end
  end
end
