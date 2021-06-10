class CreateEvidenceSubmission < ActiveRecord::Migration[6.0]
  def change
    create_table :appeals_api_evidence_submissions do |t|
      t.string :status, null: false, default: 'pending'
      t.references :supportable, polymorphic: true, type: :string, index: { name: 'evidence_submission_supportable_id_type_index' }

      t.timestamps
    end
  end
end
