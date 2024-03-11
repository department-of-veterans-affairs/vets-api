class CreateLighthouse526DocumentUploads < ActiveRecord::Migration[7.0]
  def change
    create_table :lighthouse526_document_uploads do |t|
      t.references :form526_submission, foreign_key: true, null: false
      t.references :form_attachment, foreign_key: true
      t.string :lighthouse_document_request_id, null: false
      t.string :aasm_state, index: true
      t.string :document_type
      t.datetime :lighthouse_processing_started_at
      t.datetime :lighthouse_processing_ended_at
      t.datetime :status_last_polled_at, index: true
      t.jsonb :error_message
      t.jsonb :last_status_response

      t.timestamps
    end
  end
end
