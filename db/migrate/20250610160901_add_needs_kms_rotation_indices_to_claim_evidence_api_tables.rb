 class AddNeedsKmsRotationIndicesClaimEvidenceAPITables < ActiveRecord::Migration
   disable_ddl_transaction!

   def change
    add_index :claims_evidence_api_submissions, :needs_kms_rotation, algorithm: :concurrently, if_not_exists: true
    add_index :claims_evidence_api_submission_attempts, :needs_kms_rotation, algorithm: :concurrently, if_not_exists: true
   end
 end
