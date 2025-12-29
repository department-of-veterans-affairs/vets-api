# frozen_string_literal: true

require 'sidekiq'
require 'pega_api/client'

# This job grabs all IVC Forms that are missing a status update from the third-party Pega
# and sends a notification email to the Pega team
module IvcChampva
  class NotifyPegaMissingFormStatusJob
    include Sidekiq::Job
    sidekiq_options retry: 3

    attr_accessor :additional_context

    def perform
      return unless Flipper.enabled?(:champva_enable_notify_pega_missing_form_status_job)

      batches = missing_status_cleanup.get_missing_statuses(silent: true, ignore_last_minute: true)

      return unless batches.any?

      current_time = Time.now.utc

      batches.each_value do |batch|
        form = batch[0] # get a representative form from this submission batch
        next if form.nil?

        # Check reporting API to see if this missing status is a false positive
        next if Flipper.enabled?(:champva_enable_pega_report_check) && num_docs_match_reports?(batch)

        elapsed_minutes = (current_time - form.created_at).to_i / 1.minute
        pega_email_threshold_hours =
          Settings.vanotify.services.ivc_champva.missing_pega_status_email_threshold_hours.presence&.to_i || 2

        if elapsed_minutes >= (pega_email_threshold_hours * 60) && !form.email_sent
          send_zsf_notification_to_pega(form, 'PEGA-TEAM_MISSING_STATUS')
        end
      end
    rescue => e
      Rails.logger.error "IVC Forms NotifyPegaMissingFormStatusJob Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    # Fires off a notification email to Pega so they know the communication status of
    # submissions with missing Pega statuses.
    #
    # @param form_data [hash] hash of form details (see `send_failure_email`)
    # @param form [IvcChampvaForm] form object in question
    def send_zsf_notification_to_pega(form, template_id)
      form_data = construct_email_payload(form, template_id)
      form_data = form_data.merge({
                                    email: Settings.vanotify.services.ivc_champva.pega_inbox_address
                                  })
      if IvcChampva::Email.new(form_data).send_email
        monitor.track_send_zsf_notification_to_pega(form_data[:form_uuid], template_id)
      else
        monitor.track_failed_send_zsf_notification_to_pega(form_data[:form_uuid], template_id)
      end
    end

    def construct_email_payload(form, template_id)
      { email: nil,
        form_number: form.form_number,
        file_count: nil,
        pega_status: form.pega_status,
        date_submitted: form.created_at.strftime('%B %d, %Y'),
        template_id:,
        form_uuid: form.form_uuid }
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

      matching_reports = pega_api_client.record_has_matching_report(batch.first)

      if batch.count == matching_reports.count
        missing_status_cleanup.manually_process_batch(batch)
        true
      else
        false
      end
    rescue PegaApiError => e
      Rails.logger.error "IVC Champva Forms - PegaApiError: #{e.message}"
      false
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
  end
end
