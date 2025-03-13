# frozen_string_literal: true

require 'sidekiq'
require 'decision_reviews/v1/service'
require 'common/exceptions/not_implemented'

module DecisionReviews
  class SavedClaimStatusUpdaterJob
    include Sidekiq::Job

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 30.minutes

    RETENTION_PERIOD = 59.days

    FORM_SUCCESSFUL_STATUS = 'complete'

    UPLOAD_SUCCESSFUL_STATUS = 'vbms'

    ERROR_STATUS = 'error'

    NOT_FOUND = 'DR_404'

    ATTRIBUTES_TO_STORE = %w[status detail createDate updateDate].freeze

    SECONDARY_FORM_ATTRIBUTES_TO_STORE = %w[status detail updated_at].freeze

    FINAL_STATUSES = %W[#{FORM_SUCCESSFUL_STATUS} #{UPLOAD_SUCCESSFUL_STATUS} #{ERROR_STATUS} #{NOT_FOUND}].freeze

    def perform
      return unless should_perform?

      StatsD.increment("#{statsd_prefix}.processing_records", records_to_update.size)

      records_to_update.each do |record|
        status, attributes = get_status_and_attributes(record)
        uploads_metadata = get_evidence_uploads_statuses(record)
        secondary_forms_complete = get_and_update_secondary_form_statuses(record)

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
        Rails.logger.error("#{log_prefix} error", { guid: record.guid, message: e.message })
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

    def service_tag
      raise Common::Exceptions::NotImplemented
    end

    def get_record_status(_guid)
      raise Common::Exceptions::NotImplemented
    end

    def get_evidence_status(_guid)
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

    def should_perform?
      enabled? && records_to_update.present?
    rescue => e
      StatsD.increment("#{statsd_prefix}.error")
      Rails.logger.error("#{log_prefix} error", { message: e.message })
    end

    def decision_review_service
      @service ||= DecisionReviews::V1::Service.new
    end

    def get_status_and_attributes(record)
      # return existing status if in one of the final status states
      metadata = JSON.parse(record.metadata || '{}')
      old_status = metadata['status']
      return [old_status, metadata.slice(*ATTRIBUTES_TO_STORE)] if FINAL_STATUSES.include? old_status

      response = get_record_status(record.guid)
      attributes = response.dig('data', 'attributes')
      status = attributes['status']

      [status, attributes]
    rescue DecisionReviews::V1::ServiceException => e
      raise e unless e.key == NOT_FOUND

      Rails.logger.error("#{log_prefix} error", { guid: record.guid, message: e.message })
      [NOT_FOUND, { 'status' => NOT_FOUND }]
    end

    def get_evidence_uploads_statuses(record)
      return [] unless evidence?

      result = []

      attachment_ids = record.appeal_submission&.appeal_submission_uploads
                             &.pluck(:lighthouse_upload_id) || []
      old_metadata = extract_uploads_metadata(record.metadata)
      attachment_ids.each do |guid|
        result << handle_evidence_status(guid, old_metadata.fetch(guid, {}))
      end

      result
    end

    def handle_evidence_status(guid, metadata)
      # return existing metadata if in one of the final status states
      status = metadata['status']
      return metadata if FINAL_STATUSES.include? status

      response = get_evidence_status(guid)
      attributes = response.dig('data', 'attributes').slice(*ATTRIBUTES_TO_STORE)
      attributes.merge('id' => guid)
    rescue DecisionReviews::V1::ServiceException => e
      raise e unless e.key == NOT_FOUND

      Rails.logger.error("#{log_prefix} get_evidence_status error", { guid:, message: e.message })
      { 'id' => guid, 'status' => NOT_FOUND }
    end

    def get_and_update_secondary_form_statuses(record)
      return true unless secondary_forms?

      all_complete = true
      return all_complete unless Flipper.enabled?(:decision_review_track_4142_submissions)

      secondary_forms = record.appeal_submission&.secondary_appeal_forms
      secondary_forms = secondary_forms&.filter { |form| form.delete_date.nil? } || []

      secondary_forms.each do |form|
        response = benefits_intake_service.get_status(uuid: form.guid).body
        attributes = response.dig('data', 'attributes').slice(*SECONDARY_FORM_ATTRIBUTES_TO_STORE)
        all_complete = false unless attributes['status'] == UPLOAD_SUCCESSFUL_STATUS
        handle_secondary_form_status_metrics_and_logging(form, attributes['status'])
        update_secondary_form_status(form, attributes)
      end

      all_complete
    end

    def handle_form_status_metrics_and_logging(record, status)
      # Skip logging and statsd metrics when there is no status change
      return if JSON.parse(record.metadata || '{}')['status'] == status

      Rails.logger.info("#{log_prefix} form status error", guid: record.guid) if status == ERROR_STATUS

      StatsD.increment("#{statsd_prefix}.status", tags: ["status:#{status}"])
    end

    def handle_secondary_form_status_metrics_and_logging(form, status)
      # Skip logging and statsd metrics when there is no status change
      return if JSON.parse(form.status || '{}')['status'] == status

      Rails.logger.info("#{log_prefix} secondary form status error", guid: form.guid) if status == ERROR_STATUS

      StatsD.increment("#{statsd_prefix}_secondary_form.status", tags: ["status:#{status}"])
    end

    def update_secondary_form_status(form, attributes)
      status = attributes['status']
      if status == UPLOAD_SUCCESSFUL_STATUS
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
        result = false unless status == UPLOAD_SUCCESSFUL_STATUS

        # Skip logging and statsd metrics when there is no status change
        next if old_uploads_metadata.dig(upload_id, 'status') == status

        if status == ERROR_STATUS
          error_type = get_error_type(upload['detail'])
          params = { guid: record.guid, lighthouse_upload_id: upload_id, detail: upload['detail'], error_type: }
          Rails.logger.info("#{log_prefix} evidence status error", params)
        end

        StatsD.increment("#{statsd_prefix}_upload.status", tags: ["status:#{status}"])
      end

      result
    end

    def record_complete?(record, status, uploads_metadata, secondary_forms_complete)
      check_attachments_status(record,
                               uploads_metadata) && secondary_forms_complete && status == FORM_SUCCESSFUL_STATUS
    end

    def extract_uploads_metadata(metadata)
      return {} if metadata.nil?

      JSON.parse(metadata).fetch('uploads', []).index_by { |upload| upload['id'] }
    end

    def get_error_type(detail)
      case detail
      when /.*Unidentified Mail: We could not associate part or all of this submission with a Vet*/i
        'unidentified-mail'
      when /.*ERR-EMMS-FAILED, Corrupted File detected.*/i
        'corrupted-file'
      when /.*ERR-EMMS-FAILED, Images failed to process.*/i
        'image-processing-failure'
      when /.*Errors: Batch Submitted with all blank Images.*/i
        'blank-images'
      when /.*Unsupported or Corrupted File type.*/i
        'unsupported-file-type'
      when /.ERR-EMMS-FAILED, EffectiveReceivedDate cannot be in the future.*/i
        'effective-received-date-error'
      else
        'unknown'
      end
    end
  end
end
