# frozen_string_literal: true

require 'sidekiq'
require 'pega_api/client'

# This job grabs all IVC Forms that are missing a status update from the third-party Pega
# Returns a sends stats to DataDog with the form ids
module IvcChampva
  class MissingFormStatusJob
    include Sidekiq::Job
    sidekiq_options retry: 3

    attr_accessor :additional_context

    def perform
      return unless Settings.ivc_forms.sidekiq.missing_form_status_job.enabled

      batches = if Flipper.enabled?(:champva_ignore_recent_missing_statuses, @current_user)
                  missing_status_cleanup.get_missing_statuses(silent: true, ignore_recent: true)
                else
                  missing_status_cleanup.get_missing_statuses(silent: true, ignore_last_minute: true)
                end

      Rails.logger.info "IVC Forms MissingFormStatusJob - Job started - batch_count: #{batches.count}"

      return unless batches.any?

      # Send the count of forms to DataDog
      StatsD.gauge('ivc_champva.forms_missing_status.count', batches.count)

      verbose_logging = Flipper.enabled?(:champva_missing_status_verbose_logging, @current_user)
      form_count = count_forms(batches)

      if verbose_logging && form_count > 10
        Rails.logger.info "IVC Forms MissingFormStatusJob - Too many forms to log details (#{form_count} forms)"
      end

      current_time = Time.now.utc
      process_batches(batches, current_time, verbose_logging, form_count)

      Rails.logger.info 'IVC Forms MissingFormStatusJob - Job completed successfully'
    rescue => e
      Rails.logger.error "IVC Forms MissingFormStatusJob Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    # Helper function to process batches of forms
    def process_batches(batches, current_time, verbose_logging, form_count)
      batches.each_value do |batch|
        form = batch[0] # get a representative form from this submission batch
        elapsed_days = (current_time - form.created_at).to_i / 1.day

        log_batch_processing(form, batch, elapsed_days)

        # Check reporting API to see if this missing status is a false positive
        next if Flipper.enabled?(:champva_enable_pega_report_check, @current_user) && num_docs_match_reports?(batch)

        send_failure_email_if_threshold_exceeded(form, elapsed_days)
        publish_missing_status_metric(form)
        log_verbose_missing_status(form, elapsed_days, verbose_logging, form_count)
      end
    end

    def log_batch_processing(form, batch, elapsed_days)
      file_names_str = batch.count <= 10 ? batch.map(&:file_name).to_s : 'Too many files to log'
      Rails.logger.info 'IVC Forms MissingFormStatusJob processing batch - ' \
                        "form_uuid: #{form.form_uuid}, form_number: #{form.form_number}, " \
                        "elapsed_days: #{elapsed_days}, local_doc_count: #{batch.count}, " \
                        "email_sent: #{form.email_sent}, file_names: #{file_names_str}"
    end

    def send_failure_email_if_threshold_exceeded(form, elapsed_days)
      threshold = Settings.vanotify.services.ivc_champva.failure_email_threshold_days.to_i || 7
      return unless elapsed_days >= threshold && !form.email_sent

      template_id = "#{form[:form_number]}-FAILURE"
      additional_context = { form_id: form[:form_number], form_uuid: form[:form_uuid] }

      send_failure_email(form, template_id, additional_context)

      Rails.logger.info 'IVC Forms MissingFormStatusJob - Failure ZSF email sent to user - ' \
                        "form_uuid: #{form.form_uuid}, form_number: #{form.form_number}, " \
                        "elapsed_days: #{elapsed_days}"
    end

    def publish_missing_status_metric(form)
      key = "#{form.form_uuid}_#{form.s3_status}_#{form.created_at.strftime('%Y%m%d_%H%M%S')}"
      StatsD.increment('ivc_champva.form_missing_status', tags: ["key:#{key}"])
    end

    def log_verbose_missing_status(form, elapsed_days, verbose_logging, form_count)
      return unless verbose_logging && form_count <= 10

      Rails.logger.info "IVC Forms MissingFormStatusJob - Missing status for Form #{form.form_uuid} " \
                        "- Elapsed days: #{elapsed_days} - File name: #{form.file_name} " \
                        "- S3 status: #{form.s3_status} - Created at: #{form.created_at.strftime('%Y%m%d_%H%M%S')}"
    end

    def count_forms(batches)
      batches.values.sum(&:count)
    end

    def construct_email_payload(form, template_id)
      { email: form.email,
        first_name: form.first_name,
        last_name: form.last_name,
        form_number: form.form_number,
        file_count: nil,
        pega_status: form.pega_status,
        date_submitted: form.created_at.strftime('%B %d, %Y'),
        template_id:,
        form_uuid: form.form_uuid }
    end

    # Sends an email to user notifying them of their submission's failure
    #
    # @param form [IvcChampvaForm] form object in question
    # @param template_id [string] key for template to use in `IvcChampva::Email::EMAIL_TEMPLATE_MAP`
    # @param additional_context [hash] contains properties form_id and form_uuid
    #   (e.g.: {form_id: '10-10d', form_uuid: '12345678-1234-5678-1234-567812345678'})
    def send_failure_email(form, template_id, additional_context)
      form_data = construct_email_payload(form, template_id)

      if (callback = Flipper.enabled?(:champva_vanotify_custom_callback, @current_user))
        form_data = form_data.merge(callback_hash)
      end

      ActiveRecord::Base.transaction do
        if IvcChampva::Email.new(form_data).send_email
          fetch_forms_by_uuid(form[:form_uuid]).update_all(email_sent: true) # rubocop:disable Rails/SkipsModelValidations
          monitor.track_missing_status_email_sent(form[:form_number]) unless callback
        else
          monitor.log_silent_failure(additional_context)
          raise ActiveRecord::Rollback, 'Pega Status Update/Action Required Email send failure'
        end
      end
    end

    # return the hash fields used for vanotify callback
    def callback_hash
      {
        callback_klass: 'IvcChampva::ZsfEmailNotificationCallback',
        callback_metadata: {
          statsd_tags: { service: 'veteran-ivc-champva-forms', function: 'IVC CHAMPVA send_failure_email' },
          additional_context:
        }
      }
    end

    def fetch_forms_by_uuid(form_uuid)
      @fetch_forms_by_uuid ||= IvcChampvaForm.where(form_uuid:)
    end

    ##
    # Checks PEGA reporting API to see if this batch's form_uuid is associated with an
    # identical number of records on PEGA's side - If so, sets these records to
    # "Manually Processed" and returns true. If the numbers differ, returns false.
    #
    # @param batch [Array<IvcChampvaForm>] An array of IVC CHAMPVA form objects with common form_uuid
    #   (representing a single user's submission, including all supporting documents)
    # @return [boolean] true if PEGA's reporting API has same number of documents for this batch; false otherwise
    def num_docs_match_reports?(batch)
      return false if batch.empty?

      form = batch.first
      matching_reports = pega_api_client.record_has_matching_report(form)
      pega_processable_batch = filter_pega_processable_files(batch)

      local_count = pega_processable_batch.count
      pega_count = matching_reports.is_a?(Array) ? matching_reports.count : 0
      counts_match = local_count == pega_count

      log_pega_report_comparison(form, batch, local_count, pega_count, counts_match)
      reconcile_batch_if_counts_match(form, batch, local_count, pega_count, counts_match)
    rescue IvcChampva::PegaApi::PegaApiError => e
      Rails.logger.error 'IVC Forms MissingFormStatusJob - PegaApiError during report check - ' \
                         "form_uuid: #{batch.first&.form_uuid}, error: #{e.message}"
      false
    end

    def log_pega_report_comparison(form, batch, local_count, pega_count, counts_match)
      file_names_str = batch.count <= 10 ? batch.map(&:file_name).to_s : 'Too many files to log'
      Rails.logger.info 'IVC Forms MissingFormStatusJob - Pega report comparison - ' \
                        "form_uuid: #{form.form_uuid}, local_pega_processable_count: #{local_count}, " \
                        "pega_report_count: #{pega_count}, counts_match: #{counts_match}, " \
                        "file_names: #{file_names_str}"
    end

    def reconcile_batch_if_counts_match(form, batch, local_count, pega_count, counts_match)
      return false unless counts_match && pega_count.positive?

      missing_status_cleanup.manually_process_batch(batch)
      Rails.logger.info 'IVC Forms MissingFormStatusJob - Batch reconciled via Pega API - ' \
                        "form_uuid: #{form.form_uuid}, doc_count: #{local_count}, new_status: Manually Processed"
      true
    end

    def monitor
      @monitor ||= IvcChampva::Monitor.new
    end

    def missing_status_cleanup
      @missing_status_cleanup ||= IvcChampva::ProdSupportUtilities::MissingStatusCleanup.new
    end

    def pega_api_client
      @pega_api_client ||= IvcChampva::PegaApi::Client.new
    end

    private

    ##
    # Filters out VES JSON files from a batch since they're sent to VES, not Pega
    #
    # @param batch [Array<IvcChampvaForm>] An array of IVC CHAMPVA form objects
    # @return [Array<IvcChampvaForm>] Filtered array excluding VES JSON files
    def filter_pega_processable_files(batch)
      batch.reject { |record| ves_json_file?(record.file_name) }
    end

    ##
    # Determines if a file is a VES JSON file based on its filename
    #
    # @param file_name [String] The name of the file to check
    # @return [Boolean] true if the file is a VES JSON file, false otherwise
    def ves_json_file?(file_name)
      return false if file_name.blank?

      file_name.include?('_ves.json')
    end
  end
end
