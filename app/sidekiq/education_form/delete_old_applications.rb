# frozen_string_literal: true

module EducationForm
  class DeleteOldApplications
    include Sidekiq::Job

    def perform
      edu_claim_ids = []
      saved_claim_ids = []
      stem_automated_decision_ids = []

      # Remove old education benefits claims and saved claims older than 2 months
      EducationBenefitsClaim.eager_load(:saved_claim)
                            .eager_load(:education_stem_automated_decision)
                            .where(form_clauses)
                            .find_each do |record|
                              edu_claim_ids << record.id
                              saved_claim_ids << record.saved_claim&.id
                              stem_automated_decision_ids << record.education_stem_automated_decision&.id
      end

      edu_claim_ids.compact!
      saved_claim_ids.compact!
      stem_automated_decision_ids.compact!

      delete_records_by_id(edu_claim_ids, saved_claim_ids, stem_automated_decision_ids)
    end

    def form_clauses
      [
        "(saved_claims.form_id != '22-10203' AND processed_at < '#{2.months.ago}')",
        "(saved_claims.form_id = '22-10203' AND processed_at < '#{1.year.ago}')"
      ].join(' OR ')
    end

    def delete_records_by_id(edu_claim_ids, saved_claim_ids, stem_automated_decision_ids)
      logger.info("Deleting #{edu_claim_ids.length} education benefits claims")
      logger.info("Deleting #{saved_claim_ids.length} saved claims")
      logger.info("Deleting #{stem_automated_decision_ids.length} stem automated decisions")

      EducationBenefitsClaim.delete(edu_claim_ids)
      SavedClaim::EducationBenefits.delete(saved_claim_ids)
      EducationStemAutomatedDecision.delete(stem_automated_decision_ids)
    end
  end
end
