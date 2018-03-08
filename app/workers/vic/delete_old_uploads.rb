# frozen_string_literal: true

module VIC
  class DeleteOldUploads
    include Sidekiq::Worker

    def perform
      s3 = Aws::S3::Resource.new

      if Rails.env.production?
        bucket = s3.bucket(Settings.vic.s3.bucket)

        bucket.objects.with_prefix('anonymous/').delete_if do |obj|
          obj.last_modified < 2.months.ago
        end
      end

      # Delete anonymous uploads older than 60 days
      bucket.objects.with_prefix

      # edu_claim_ids = []
      # saved_claim_ids = []

      # # Remove old education benefits claims and saved claims older than 2 months
      # EducationBenefitsClaim.eager_load(:saved_claim)
      #                       .where("processed_at < '#{2.months.ago}'")
      #                       .find_each do |record|
      #   edu_claim_ids << record.id
      #   saved_claim_ids << record&.saved_claim.id
      # end

      # edu_claim_ids.compact!
      # saved_claim_ids.compact!

      # logger.info("Deleting #{edu_claim_ids.length} education benefits claims")
      # logger.info("Deleting #{saved_claim_ids.length} saved claims")

      # EducationBenefitsClaim.delete(edu_claim_ids)
      # SavedClaim::EducationBenefits.delete(saved_claim_ids)
    end
  end
end
