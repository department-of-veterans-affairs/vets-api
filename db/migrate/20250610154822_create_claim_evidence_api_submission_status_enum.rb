class CreateClaimEvidenceAPISubmissionStatusEnum < ActiveRecord::Migration[7.2]
  def change
    create_enum :claims_evidence_api_submission_status, %w[pending accepted failed]
  end
end
