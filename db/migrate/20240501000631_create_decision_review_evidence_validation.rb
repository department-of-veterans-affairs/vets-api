class CreateDecisionReviewEvidenceValidation < ActiveRecord::Migration[7.1]
  def change
    create_table :decision_review_evidence_validations do |t|
      t.uuid :decision_review_guid
      t.text :password_ciphertext
      t.text :encrypted_kms_key

      t.timestamps
    end
  end
end
