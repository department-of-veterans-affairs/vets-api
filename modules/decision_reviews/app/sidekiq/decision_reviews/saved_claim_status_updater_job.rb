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

    SECONDARY_FORM_ATTRIBUTES_TO_STORE = %w[status detail updated_at final_status].freeze

    FINAL_STATUSES = %W[#{FORM_SUCCESSFUL_STATUS} #{UPLOAD_SUCCESSFUL_STATUS} #{ERROR_STATUS} #{NOT_FOUND}].freeze

    BATCH_SIZE = 100

    def perform
      return unless should_perform?

      StatsD.increment("#{statsd_prefix}.processing_records", records_to_update.count)

      records_to_update.find_each(batch_size: BATCH_SIZE) do |record|
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

    def should_perform?
      records_to_update.present?
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

      # Monitor for forms stuck >30 days in non-final status
      # Only check after fresh API poll to ensure we have current status before alerting
      monitor_stuck_form_with_metadata(record, status, metadata) if decision_review_stuck_records_monitoring_enabled?

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

        # Monitor for evidence uploads stuck >30 days in non-final status
        # Only check after fresh API poll to ensure we have current status before alerting
        monitor_stuck_evidence_upload(record, guid, result.last) if decision_review_stuck_records_monitoring_enabled?
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

      secondary_forms = record.appeal_submission&.secondary_appeal_forms
      secondary_forms = secondary_forms&.filter { |form| form.delete_date.nil? } || []

      return true if secondary_forms.empty?

      # Branch to separate implementations for clean feature flag removal
      if decision_review_final_status_polling_enabled?
        process_secondary_forms_enhanced(secondary_forms)
      else
        process_secondary_forms_legacy(secondary_forms)
      end
    end

    def process_secondary_forms_enhanced(secondary_forms)
      all_complete = true

      secondary_forms.each do |form|
        current_status = parse_form_status(form)

        if should_continue_polling?(current_status)
          response = benefits_intake_service.get_status(uuid: form.guid).body
          attributes = response.dig('data', 'attributes').slice(*SECONDARY_FORM_ATTRIBUTES_TO_STORE)
          form_is_complete = attributes['status'] == UPLOAD_SUCCESSFUL_STATUS &&
                             attributes['final_status'] == true
          all_complete = false unless form_is_complete

          handle_secondary_form_status_metrics_and_logging(form, attributes['status'])
          update_secondary_form_status_enhanced(form, attributes)
          current_status = attributes
        end

        monitor_temporary_error_form(form, current_status)
      end

      all_complete
    end

    def process_secondary_forms_legacy(secondary_forms)
      all_complete = true

      secondary_forms.each do |form|
        response = benefits_intake_service.get_status(uuid: form.guid).body
        legacy_attributes = %w[status detail updated_at]
        attributes = response.dig('data', 'attributes').slice(*legacy_attributes)
        all_complete = false unless attributes['status'] == UPLOAD_SUCCESSFUL_STATUS
        handle_secondary_form_status_metrics_and_logging(form, attributes['status'])
        update_secondary_form_status_legacy(form, attributes)
      end

      all_complete
    end

    def monitor_temporary_error_form(form, current_status)
      return unless current_status['status'] == 'error' && current_status['final_status'] != true

      # Ideally we'd track when status first became "error", but since errors are rare,
      # we can just use the form.created_at field as a comparison

      error_timestamp = form.created_at
      days_in_error = (Time.current - error_timestamp) / 1.day

      return unless days_in_error > 15

      Rails.logger.info(
        "#{log_prefix} secondary form stuck in non-final error state",
        {
          secondary_form_uuid: form.guid,
          appeal_submission_id: form.appeal_submission_id,
          days_in_error: days_in_error.round(2),
          status_updated_at: form.status_updated_at
        }
      )
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

    def update_secondary_form_status_enhanced(form, attributes)
      status = attributes['status']
      final_status = attributes['final_status']

      if status == UPLOAD_SUCCESSFUL_STATUS && final_status == true
        StatsD.increment("#{statsd_prefix}_secondary_form.delete_date_update")
        delete_date = (Time.current + RETENTION_PERIOD)
      else
        delete_date = nil
      end
      form.update!(status: attributes.to_json, status_updated_at: Time.current, delete_date:)
    end

    def update_secondary_form_status_legacy(form, attributes)
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

    def should_continue_polling?(current_status)
      # Continue polling unless explicitly marked as final
      current_status['final_status'] != true
    end

    def parse_form_status(form)
      JSON.parse(form.status || '{}')
    rescue JSON::ParserError => e
      Rails.logger.error(
        "#{log_prefix} Malformed JSON in secondary form status",
        { guid: form.guid, status: form.status, error: e.message }
      )
      {}
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

    def monitor_stuck_form_with_metadata(record, status, _metadata)
      monitor_stuck_record(
        record:,
        status:,
        type: 'form',
        additional_context: {}
      )
    end

    def monitor_stuck_evidence_upload(record, upload_id, upload_data)
      monitor_stuck_record(
        record:,
        status: upload_data['status'],
        type: 'evidence',
        additional_context: { upload_id: }
      )
    end

    def monitor_stuck_record(record:, status:, type:, additional_context:)
      stuck_threshold = 30.days.ago

      # Use created_at to measure how long submission has existed (not when status last changed)
      # This gives consistent age measurement since updated_at changes with every polling cycle
      return unless FINAL_STATUSES.exclude?(status) && record.created_at < stuck_threshold

      days_stuck = (Time.current - record.created_at) / 1.day.to_f

      log_context = {
        appeal_submission_id: record.appeal_submission&.id,
        days_stuck: days_stuck.round(2),
        created_at: record.created_at,
        current_status: status
      }.merge(additional_context)

      Rails.logger.warn("#{log_prefix} #{type} stuck in non-final status", log_context)
    end

    # Feature flag helpers for clean removal later
    def decision_review_final_status_polling_enabled?
      Flipper.enabled?(:decision_review_final_status_polling)
    end

    def decision_review_stuck_records_monitoring_enabled?
      Flipper.enabled?(:decision_review_stuck_records_monitoring)
    end
  end
end
