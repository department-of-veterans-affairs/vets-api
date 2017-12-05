# frozen_string_literal: true
module EducationForm
  class DeleteOldApplications
    include Sidekiq::Worker

    def perform
      edu_claim_ids = []
      saved_claim_ids = []

      # Remove old education benefits claims and saved claims older than 2 months
      EducationBenefitsClaim.eager_load(:saved_claim)
                            .where("processed_at < '#{2.months.ago}'")
                            .find_each do |record|
        edu_claim_ids << record.id
        saved_claim_ids << record&.saved_claim.id
      end

      edu_claim_ids.compact!
      saved_claim_ids.compact!

      logger.info("Deleting #{edu_claim_ids.length} education benefits claims")
      logger.info("Deleting #{saved_claim_ids.length} saved claims")

      EducationBenefitsClaim.delete(edu_claim_ids)
      SavedClaim::EducationBenefits.delete(saved_claim_ids)
    end
  end
end
