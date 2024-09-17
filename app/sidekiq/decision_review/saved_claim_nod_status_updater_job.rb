# frozen_string_literal: true

require 'sidekiq'
require 'decision_review_v1/service'

module DecisionReview
  class SavedClaimNodStatusUpdaterJob
    include Sidekiq::Job

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 30.minutes

    RETENTION_PERIOD = 59.days

    SUCCESSFUL_STATUS = %w[complete].freeze

    UPLOAD_SUCCESSFUL_STATUS = %w[vbms].freeze

    ATTRIBUTES_TO_STORE = %w[status detail createDate updateDate].freeze

    STATSD_KEY_PREFIX = 'worker.decision_review.saved_claim_nod_status_updater'

    def perform
      return unless enabled? && notice_of_disagreements.present?

      StatsD.increment("#{STATSD_KEY_PREFIX}.processing_records", notice_of_disagreements.size)

      notice_of_disagreements.each do |nod|
        guid = nod.guid
        status, attributes = get_status_and_attributes(guid)
        uploads_metadata = get_evidence_uploads_statuses(guid)

        timestamp = DateTime.now
        params = { metadata: attributes.merge(uploads: uploads_metadata).to_json, metadata_updated_at: timestamp }

        # only set delete date if attachments are all successful as well
        if all_uploads_successful?(uploads_metadata) && SUCCESSFUL_STATUS.include?(status)
          params[:delete_date] = timestamp + RETENTION_PERIOD
          StatsD.increment("#{STATSD_KEY_PREFIX}.delete_date_update")
        else
          StatsD.increment("#{STATSD_KEY_PREFIX}.status", tags: ["status:#{status}"])
        end

        nod.update(params)
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.error")
        Rails.logger.error('DecisionReview::SavedClaimNodStatusUpdaterJob error', { guid:, message: e.message })
      end

      nil
    end

    private

    def decision_review_service
      @service ||= DecisionReviewV1::Service.new
    end

    def notice_of_disagreements
      @notice_of_disagreements ||= ::SavedClaim::NoticeOfDisagreement.where(delete_date: nil).order(created_at: :asc)
    end

    def get_status_and_attributes(guid)
      response = decision_review_service.get_notice_of_disagreement(guid).body
      attributes = response.dig('data', 'attributes')
      status = attributes['status']

      [status, attributes]
    end

    def get_evidence_uploads_statuses(submitted_appeal_uuid)
      result = []

      attachment_ids = AppealSubmission.find_by(submitted_appeal_uuid:)&.appeal_submission_uploads
                                       &.pluck(:lighthouse_upload_id) || []

      attachment_ids.each do |guid|
        response = decision_review_service.get_notice_of_disagreement_upload(guid:).body
        attributes = response.dig('data', 'attributes').slice(*ATTRIBUTES_TO_STORE)
        result << attributes.merge('id' => guid)
      end

      result
    end

    def all_uploads_successful?(uploads_metadata)
      result = true

      uploads_metadata.each do |upload|
        status = upload['status']
        result = false unless UPLOAD_SUCCESSFUL_STATUS.include? status
        StatsD.increment("#{STATSD_KEY_PREFIX}_upload.status", tags: ["status:#{status}"])
      end

      result
    end

    def enabled?
      Flipper.enabled? :decision_review_saved_claim_nod_status_updater_job_enabled
    end
  end
end
