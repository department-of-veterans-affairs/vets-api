# frozen_string_literal: true

# create status enum
class CreateClaimEvidenceApiSubmissionStatusEnum < ActiveRecord::Migration[7.2]

  # create the enum
  def change
    create_enum :claims_evidence_api_submission_status, %w[pending accepted failed]
  end
end
