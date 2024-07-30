# frozen_string_literal: true

require 'sidekiq'
require 'decision_review_v1/service'

module DecisionReview
  class SavedClaimScStatusUpdaterJob
    include Sidekiq::Job

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 30.minutes

    RETENTION_PERIOD = 59.days

    SUCCESSFUL_STATUS = %w[complete].freeze

    def perform
      return unless enabled? && supplemental_claims.present?

      supplemental_claims.each do |sc|
        guid = sc.guid
        status = decision_review_service.get_supplemental_claim(guid).dig('data', 'attributes', 'status')

        # check status of SC and update delete_date
        if SUCCESSFUL_STATUS.include? status
          sc.update(delete_date: DateTime.now + RETENTION_PERIOD)
          Rails.logger.info("#{self.class.name} updated delete_date", guid:)
        end
      end
    end

    private

    def decision_review_service
      @service ||= DecisionReviewV1::Service.new
    end

    def supplemental_claims
      @supplemental_claims ||= ::SavedClaim::SupplementalClaim.where(delete_date: nil).order(created_at: :asc)
    end

    def enabled?
      Flipper.enabled? :decision_review_saved_claim_sc_status_updater_job_enabled
    end
  end
end
