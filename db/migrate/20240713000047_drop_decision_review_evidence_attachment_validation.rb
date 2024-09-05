class DropDecisionReviewEvidenceAttachmentValidation < ActiveRecord::Migration[7.1]
  def change
    remove_index :decision_review_evidence_attachment_validations, column: :decision_review_evidence_attachment_guid, name: "index_dr_evidence_attachment_validation_on_guid"
    drop_table :decision_review_evidence_attachment_validations
  end
end
