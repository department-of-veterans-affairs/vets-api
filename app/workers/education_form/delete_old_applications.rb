# frozen_string_literal: true
module EducationForm
  class DeleteOldApplications
    include Sidekiq::Worker

    def perform
      records = EducationBenefitsClaim.where("processed_at < '#{1.month.ago}'")
      logger.info("Deleting #{records.count} old 22-1990s")
      records.delete_all
    end
  end
end
