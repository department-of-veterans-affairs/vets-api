class AddStatusToEvidenceWaiverSubmission < ActiveRecord::Migration[6.1]
  def change
    add_column :claims_api_evidence_waiver_submissions, :status, :string
  end
end
