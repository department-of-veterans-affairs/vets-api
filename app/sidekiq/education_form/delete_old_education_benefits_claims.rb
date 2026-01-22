# frozen_string_literal: true

module EducationForm
  class DeleteOldEducationBenefitsClaims
    include Sidekiq::Job

    FORM_TYPES = %w[
      22-0803
      22-0839
      22-0976
      22-1919
      22-8794
      22-10203
      22-10215
      22-10216
      22-10272
      22-10275
      22-10278
      22-10282
      22-10297
    ].freeze

    def perform
      records = SavedClaim.where(form_id: FORM_TYPES).where('delete_date < ?', Time.zone.now)
      logger.info("DeleteOldEducationBenefitsClaims: deleting #{records.count} claims records")

      records.each do |record|
        record.destroy
      rescue => e
        logger.error("DeleteOldEducationBenefitsClaims: failed to delete claim #{record.id}, #{e.message}")
      end
    end
  end
end
