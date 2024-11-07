# frozen_string_literal: true

require_relative 'saved_claim_status_updater_job'

module DecisionReview
  class ScStatusUpdaterJob < SavedClaimStatusUpdaterJob

    SECONDARY_FORM_ATTRIBUTES_TO_STORE = %w[status detail updated_at].freeze

    def perform
      return unless enabled? && records_to_update.present?

      StatsD.increment("#{statsd_prefix}.processing_records", records_to_update.size)

      records_to_update.each do |sc|
        status, attributes = get_status_and_attributes(sc.guid)
        uploads_metadata = get_evidence_uploads_statuses(sc.guid)
        secondary_forms_complete = get_and_update_secondary_form_statuses(sc.guid)

        timestamp = DateTime.now
        params = { metadata: attributes.merge(uploads: uploads_metadata).to_json, metadata_updated_at: timestamp }
        # only set delete date if attachments are all successful as well
        if saved_claim_complete?(sc, status, uploads_metadata, secondary_forms_complete)
          params[:delete_date] = timestamp + RETENTION_PERIOD
          StatsD.increment("#{statsd_prefix}.delete_date_update")
        else
          handle_form_status_metrics_and_logging(sc, status)
        end

        sc.update(params)
      rescue => e
        StatsD.increment("#{statsd_prefix}.error")
        Rails.logger.error("#{log_prefix} error", { guid: sc.guid, message: e.message })
      end

      nil
    end

    private

    def records_to_update
      @supplemental_claims ||= ::SavedClaim::SupplementalClaim.where(delete_date: nil).order(created_at: :asc)
    end

    def statsd_prefix
      'worker.decision_review.saved_claim_sc_status_updater'
    end

    def log_prefix
      'DecisionReview::SavedClaimScStatusUpdaterJob'
    end

    def get_record_status(guid)
      decision_review_service.get_supplemental_claim(guid).body
    end

    def get_evidence_status(uuid)
      decision_review_service.get_supplemental_claim_upload(uuid:).body
    end

    def benefits_intake_service
      @intake_service ||= BenefitsIntake::Service.new
    end

    def get_and_update_secondary_form_statuses(submitted_appeal_uuid)
      all_complete = true
      return all_complete unless Flipper.enabled?(:decision_review_track_4142_submissions)

      secondary_forms = AppealSubmission.find_by(submitted_appeal_uuid:)&.secondary_appeal_forms
      secondary_forms = secondary_forms&.filter { |form| form.delete_date.nil? } || []

      secondary_forms.each do |form|
        response = benefits_intake_service.get_status(uuid: form.guid).body
        attributes = response.dig('data', 'attributes').slice(*SECONDARY_FORM_ATTRIBUTES_TO_STORE)
        all_complete = false unless UPLOAD_SUCCESSFUL_STATUS.include?(attributes['status'])
        handle_secondary_form_status_metrics_and_logging(form, attributes['status'])
        update_secondary_form_status(form, attributes)
      end

      all_complete
    end

    def handle_secondary_form_status_metrics_and_logging(form, status)
      # Skip logging and statsd metrics when there is no status change
      return if JSON.parse(form.status || '{}')['status'] == status

      if status == ERROR_STATUS
        Rails.logger.info("#{log_prefix} secondary form status error", guid: form.guid)
        tags = ['service:supplemental-claims-4142', 'function: PDF submission to Lighthouse']
        StatsD.increment('silent_failure', tags:)
      end

      StatsD.increment("#{statsd_prefix}_secondary_form.status", tags: ["status:#{status}"])
    end

    def update_secondary_form_status(form, attributes)
      status = attributes['status']
      if UPLOAD_SUCCESSFUL_STATUS.include?(status)
        StatsD.increment("#{statsd_prefix}_secondary_form.delete_date_update")
        delete_date = (Time.current + RETENTION_PERIOD)
      else
        delete_date = nil
      end
      form.update!(status: attributes.to_json, status_updated_at: Time.current, delete_date:)
    end

    def saved_claim_complete?(sc, status, uploads_metadata, secondary_forms_complete)
      check_attachments_status(sc, uploads_metadata) && secondary_forms_complete && SUCCESSFUL_STATUS.include?(status)
    end

    def enabled?
      Flipper.enabled? :decision_review_saved_claim_sc_status_updater_job_enabled
    end
  end
end
