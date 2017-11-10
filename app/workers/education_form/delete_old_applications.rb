# frozen_string_literal: true
module EducationForm
  class DeleteOldApplications
    include Sidekiq::Worker

    def perform
      edu_claim_ids = []
      edu_submission_ids = []
      saved_claim_ids = []

      EducationBenefitsClaim.where("processed_at < '#{2.months.ago}'").find_each do |record|
        edu_claim_ids << record.id
        edu_submission_ids << record&.education_benefits_submission.id
        saved_claim_ids << record&.saved_claim.id
      end

      edu_claim_ids.compact!
      edu_submission_ids.compact!
      saved_claim_ids.compact!

      total = edu_claim_ids.length + edu_submission_ids.length + saved_claim_ids.length

      logger.info("Deleting #{total} total old records")
      logger.info("Deleting #{edu_claim_ids.length} old education benefits claims")
      logger.info("Deleting #{edu_submission_ids.length} old education benefits submissions")
      logger.info("Deleting #{saved_claim_ids.length} old saved claims")

      EducationBenefitsSubmission.delete(edu_submission_ids)
      EducationBenefitsClaim.delete(edu_claim_ids)
      SavedClaim.delete(saved_claim_ids)
    end
  end
end
