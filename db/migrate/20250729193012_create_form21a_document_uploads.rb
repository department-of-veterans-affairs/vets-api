class CreateForm21aDocumentUploads < ActiveRecord::Migration[7.2]
  def change
    create_table :form21a_document_uploads do |t|
      t.integer :gclaws_document_type
      t.boolean :gclaws_upload_failed
      t.references :form_attachment, null: false, foreign_key: true
      t.references :in_progress_form, null: false, foreign_key: true
      t.references :user_account, type: :uuid, foreign_key: :true, null: :false

      t.timestamps
    end
  end
end
