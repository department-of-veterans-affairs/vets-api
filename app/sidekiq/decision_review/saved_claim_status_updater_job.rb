# frozen_string_literal: true

require 'sidekiq'
require 'decision_review_v1/service'
require 'common/exceptions/not_implemented'

module DecisionReview
  class SavedClaimStatusUpdaterJob
    include Sidekiq::Job

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 30.minutes

    RETENTION_PERIOD = 59.days

    SUCCESSFUL_STATUS = %w[complete].freeze

    ERROR_STATUS = 'error'

    UPLOAD_SUCCESSFUL_STATUS = %w[vbms].freeze

    ATTRIBUTES_TO_STORE = %w[status detail createDate updateDate].freeze

    SECONDARY_FORM_ATTRIBUTES_TO_STORE = %w[status detail updated_at].freeze

    def perform
      return unless enabled? && records_to_update.present?

      StatsD.increment("#{statsd_prefix}.processing_records", records_to_update.size)

      records_to_update.each do |record|
        guid = record.guid
        status, attributes = get_status_and_attributes(guid)
        uploads_metadata = get_evidence_uploads_statuses(guid)
        secondary_forms_complete = get_and_update_secondary_form_statuses(guid)

        timestamp = DateTime.now
        params = { metadata: attributes.merge(uploads: uploads_metadata).to_json, metadata_updated_at: timestamp }

        # only set delete date if attachments are all successful as well
        if record_complete?(record, status, uploads_metadata, secondary_forms_complete)
          params[:delete_date] = timestamp + RETENTION_PERIOD
          StatsD.increment("#{statsd_prefix}.delete_date_update")
        else
          handle_form_status_metrics_and_logging(record, status)
        end

        record.update(params)
      rescue => e
        StatsD.increment("#{statsd_prefix}.error")
        Rails.logger.error("#{log_prefix} error", { guid:, message: e.message })
      end

      nil
    end

    private

    def records_to_update
      raise Common::Exceptions::NotImplemented
    end

    def statsd_prefix
      raise Common::Exceptions::NotImplemented
    end

    def log_prefix
      raise Common::Exceptions::NotImplemented
    end

    def get_record_status(guid)
      raise Common::Exceptions::NotImplemented
    end

    def get_evidence_status(guid)
      raise Common::Exceptions::NotImplemented
    end

    def evidence?
      raise Common::Exceptions::NotImplemented
    end

    def secondary_forms?
      raise Common::Exceptions::NotImplemented
    end

    def enabled?
      raise Common::Exceptions::NotImplemented
    end

    def decision_review_service
      @service ||= DecisionReviewV1::Service.new
    end

    def get_status_and_attributes(guid)
      response = get_record_status(guid)
      attributes = response.dig('data', 'attributes')
      status = attributes['status']

      [status, attributes]
    end

    def get_evidence_uploads_statuses(submitted_appeal_uuid)
      return [] unless evidence?

      result = []

      attachment_ids = AppealSubmission.find_by(submitted_appeal_uuid:)&.appeal_submission_uploads
                                       &.pluck(:lighthouse_upload_id) || []

      attachment_ids.each do |guid|
        response = get_evidence_status(guid)
        attributes = response.dig('data', 'attributes').slice(*ATTRIBUTES_TO_STORE)
        result << attributes.merge('id' => guid)
      end

      result
    end

    def get_and_update_secondary_form_statuses(submitted_appeal_uuid)
      return true unless secondary_forms?

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

    def handle_form_status_metrics_and_logging(record, status)
      # Skip logging and statsd metrics when there is no status change
      return if JSON.parse(record.metadata || '{}')['status'] == status

      if status == ERROR_STATUS
        Rails.logger.info("#{log_prefix} form status error", guid: record.guid)
        tags = ['service:board-appeal', 'function: form submission to Lighthouse']
        StatsD.increment('silent_failure', tags:)
      end

      StatsD.increment("#{statsd_prefix}.status", tags: ["status:#{status}"])
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

    def check_attachments_status(record, uploads_metadata)
      result = true

      old_uploads_metadata = extract_uploads_metadata(record.metadata)

      uploads_metadata.each do |upload|
        status = upload['status']
        upload_id = upload['id']
        result = false unless UPLOAD_SUCCESSFUL_STATUS.include? status

        # Skip logging and statsd metrics when there is no status change
        next if old_uploads_metadata.dig(upload_id, 'status') == status

        if status == ERROR_STATUS
          Rails.logger.info("#{log_prefix} evidence status error",
                            { guid: record.guid, lighthouse_upload_id: upload_id, detail: upload['detail'] })
          tags = ['service:board-appeal', 'function: evidence submission to Lighthouse']
          StatsD.increment('silent_failure', tags:)
        end

        StatsD.increment("#{statsd_prefix}_upload.status", tags: ["status:#{status}"])
      end

      result
    end

    def record_complete?(record, status, uploads_metadata, secondary_forms_complete)
      check_attachments_status(record,
                               uploads_metadata) && secondary_forms_complete && SUCCESSFUL_STATUS.include?(status)
    end

    def extract_uploads_metadata(metadata)
      return {} if metadata.nil?

      JSON.parse(metadata).fetch('uploads', []).index_by { |upload| upload['id'] }
    end
  end
end
