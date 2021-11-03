class AddEvidenceSubmissionIndicatedToAppealApiSupplementalClaim < ActiveRecord::Migration[6.1]
  def change
    add_column :appeals_api_supplemental_claims, :evidence_submission_indicated, :boolean
  end
end
