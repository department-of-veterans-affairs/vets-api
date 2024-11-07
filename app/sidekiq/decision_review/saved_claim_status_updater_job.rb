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

    def perform
      return unless enabled? && records_to_update.present?
      pp "Got in perform method"

      StatsD.increment("#{statsd_prefix}.processing_records", records_to_update.size)

      records_to_update.each do |record|
        guid = record.guid
        status, attributes = get_status_and_attributes(guid)
        uploads_metadata = get_evidence_uploads_statuses(guid)

        timestamp = DateTime.now
        params = { metadata: attributes.merge(uploads: uploads_metadata).to_json, metadata_updated_at: timestamp }

        # only set delete date if attachments are all successful as well
        if check_attachments_status(record, uploads_metadata) && SUCCESSFUL_STATUS.include?(status)
          params[:delete_date] = timestamp + RETENTION_PERIOD
          StatsD.increment("#{statsd_prefix}.delete_date_update")
        else
          handle_form_status_metrics_and_logging(record, status)
        end

        record.update(params)
      rescue => e
        pp "Got and error #{e.message}"
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

    def extract_uploads_metadata(metadata)
      return {} if metadata.nil?

      JSON.parse(metadata).fetch('uploads', []).index_by { |upload| upload['id'] }
    end
  end
end
