class CreateLighthouseDocumentUploads < ActiveRecord::Migration[7.0]
  def change
    create_table :lighthouse_document_uploads do |t|
      t.references :form526_submission, foreign_key: true, null: false
      t.references :form_attachment, foreign_key: true
      t.string :lighthouse_document_request_id, null: false
      t.string :aasm_state
      t.string :document_type
      t.datetime :lighthouse_processing_started_at
      t.datetime :lighthouse_processing_ended_at
      t.jsonb :error_message

      t.timestamps
    end    
  end
end
