class AddUploadSubmissionToEvidenceSubmissions < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_column :appeals_api_evidence_submissions, :guid, :uuid, null: false
      add_index :appeals_api_evidence_submissions, :guid
      add_reference :appeals_api_evidence_submissions,
                    :upload_submission,
                    type: :int, # The same as the `vba_documents_upload_submissions` PK type
                    null: false,
                    index: { unique: true, algorithm: :concurrently }
      remove_column :appeals_api_evidence_submissions, :status, :string
      rename_column :appeals_api_evidence_submissions, :details, :detail
    end
  end
end
