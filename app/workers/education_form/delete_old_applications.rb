# frozen_string_literal: true
module EducationForm
  class DeleteOldApplications
    include Sidekiq::Worker

    def perform
      edu_claim_ids = []
      edu_submission_ids = []
      saved_claim_ids = []

      old_education_benefits_claims.find_each do |r|
        edu_claim_ids << r.id
        edu_submission_ids << r&.education_benefits_submission.id
        saved_claim_ids << r&.saved_claim.id
      end

      edu_claim_ids.compact!
      edu_submission_ids.compact!
      saved_claim_ids.compact!

      total = edu_claim_ids.length + edu_submission_ids.length + saved_claim_ids.length

      logger.info("Deleting #{total} total old records")
      logger.info("Deleting #{edu_claim_ids.length} old education benefits claims")
      logger.info("Deleting #{edu_submission_ids.length} old education benefits submissions")
      logger.info("Deleting #{saved_claim_ids.length} old saved claims")

      EducationBenefitsSubmission.delete(edu_submission_ids.compact)
      EducationBenefitsClaim.delete(edu_claim_ids.compact)
      SavedClaim.delete(saved_claim_ids)
    end

    def old_education_benefits_claims
      EducationBenefitsClaim.includes(:saved_claim)
                            .includes(:education_benefits_submission)
                            .where("processed_at < '#{2.months.ago}'")
    end
  end
end
