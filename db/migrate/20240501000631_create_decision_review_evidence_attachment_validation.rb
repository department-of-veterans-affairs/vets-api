class CreateDecisionReviewEvidenceAttachmentValidation < ActiveRecord::Migration[7.1]
  def change
    create_table :decision_review_evidence_attachment_validations do |t|
      t.uuid :decision_review_evidence_attachment_guid, null: false
      t.text :password_ciphertext
      t.text :encrypted_kms_key

      t.timestamps

      t.index :decision_review_evidence_attachment_guid, name: "index_dr_evidence_attachment_validation_on_guid"
    end
  end
end
