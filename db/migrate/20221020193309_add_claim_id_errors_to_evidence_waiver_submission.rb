class AddClaimIdErrorsToEvidenceWaiverSubmission < ActiveRecord::Migration[6.1]
  def change
    add_column :claims_api_evidence_waiver_submissions, :vbms_error_message, :string
    add_column :claims_api_evidence_waiver_submissions, :bgs_error_message, :string
    add_column :claims_api_evidence_waiver_submissions, :vbms_upload_failure_count, :integer, default: 0
    add_column :claims_api_evidence_waiver_submissions, :bgs_upload_failure_count, :integer, default: 0
    add_column :claims_api_evidence_waiver_submissions, :claim_id, :string
  end
end
