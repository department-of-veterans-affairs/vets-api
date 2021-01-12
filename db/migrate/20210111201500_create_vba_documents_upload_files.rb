class CreateVBADocumentsUploadFiles < ActiveRecord::Migration[6.0]
  def change
    create_table(:vba_documents_upload_files) do |t|
      t.string :guid
      t.timestamps null: false
      t.json :metadata
    end
    add_index(:vba_documents_upload_files, [:guid])
  end
end
