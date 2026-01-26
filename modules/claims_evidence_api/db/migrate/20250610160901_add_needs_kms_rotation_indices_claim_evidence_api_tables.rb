# frozen_string_literal: true

# add kms rotation indexes
class AddNeedsKmsRotationIndicesClaimEvidenceApiTables < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  # add the index
  def change
    add_index :claims_evidence_api_submissions, :needs_kms_rotation, algorithm: :concurrently, if_not_exists: true
    add_index :claims_evidence_api_submission_attempts, :needs_kms_rotation, algorithm: :concurrently, if_not_exists: true
  end
end
