# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module IvcChampva
  class Monitor < ::ZeroSilentFailures::Monitor
    STATS_KEY = 'api.ivc_champva_form'

    def initialize
      super('veteran-ivc-champva-forms')
    end

    # form_uuid: string of the uuid included in a form's metadata
    # form_id: string of the form's government ID (e.g., 10-10d)
    def track_insert_form(form_uuid, form_id)
      additional_context = {
        form_uuid:,
        form_id:
      }
      track_request('info', "IVC ChampVA Forms - #{form_id} inserted into database", "#{STATS_KEY}.insert_form",
                    call_location: caller_locations.first, **additional_context)
    end

    # form_uuid: string of the uuid included in a form's metadata
    # status: string of new Pega status being applied to form
    def track_update_status(form_uuid, status)
      additional_context = {
        form_uuid:,
        status:
      }
      track_request('info', "IVC ChampVA Forms - #{form_uuid} status updated to #{status}",
                    "#{STATS_KEY}.update_status",
                    call_location: caller_locations.first, **additional_context)
    end

    ##
    # Logs relevant context to data dog when an IVC email has been sent via VA Notify.
    # This method is intended to be invoked inside a custom VA Notify `callback_klass`
    #
    # @param [String] form_id Form's government ID (e.g., '10-10d')
    # @param [String] form_uuid UUID generated for this particular form submission
    # @param [String] delivery_status Status provided via VA Notify callback (e.g., 'delivered' or 'permanent-failure')
    # @param [String] notification_type Kind of notification (e.g., 'confirmation', 'failure')
    #
    # @return
    def track_email_sent(form_id, form_uuid, delivery_status, notification_type)
      additional_context = {
        form_id:,
        form_uuid:,
        delivery_status:,
        notification_type:
      }
      track_request('info', "IVC ChampVA Forms - #{delivery_status} #{form_id} #{notification_type}
                    email for submission with UUID #{form_uuid}",
                    "#{STATS_KEY}.email_sent",
                    call_location: caller_locations.first, **additional_context)
    end

    # form_id: string of the form's government ID (e.g., 10-10d)
    def track_missing_status_email_sent(form_id)
      # TODO: add form_uuid as a param so we can better understand WHO got the email
      additional_context = {
        form_id:
      }
      track_request('info', "IVC ChampVA Forms - #{form_id} missing status failure email sent",
                    "#{STATS_KEY}.form_missing_status_email_sent",
                    call_location: caller_locations.first, **additional_context)
    end

    def track_send_zsf_notification_to_pega(form_uuid, template_id)
      additional_context = {
        form_uuid:,
        template_id:
      }
      track_request('info', "IVC ChampVA Forms - Sent notification to Pega for submission #{form_uuid}",
                    "#{STATS_KEY}.send_zsf_notification_to_pega",
                    call_location: caller_locations.first, **additional_context)
    end

    def track_failed_send_zsf_notification_to_pega(form_uuid, template_id)
      additional_context = {
        form_uuid:,
        template_id:
      }
      track_request('warn', "IVC ChampVA Forms - Failed to send notification to Pega for submission #{form_uuid}",
                    "#{STATS_KEY}.failed_send_zsf_notification_to_pega",
                    call_location: caller_locations.first, **additional_context)
    end

    def track_all_successful_s3_uploads(key)
      additional_context = {
        key:
      }
      track_request('info', "IVC ChampVA Forms - uploaded into S3 bucket #{key}",
                    "#{STATS_KEY}.s3_upload.success",
                    call_location: caller_locations.first, **additional_context)
    end

    def track_s3_put_object_error(key, error, response = nil)
      additional_context = {
        key:,
        error_message: error.message,
        error_class: error.class.name,
        backtrace: error.backtrace&.join("\n") # Safe navigation operator
      }
      if response.respond_to?(:status)
        additional_context[:status_code] = response.status
        if response.respond_to?(:body) && response.body.respond_to?(:read)
          additional_context[:response_body] = response.body.read
        end
      end
      track_request('error', 'IVC ChampVA Forms - S3 PutObject failure',
                    "#{STATS_KEY}.s3_upload.failure", # Consistent stats key
                    call_location: caller_locations.first, **additional_context)
    end

    def track_s3_upload_file_error(key, error)
      additional_context = {
        key:,
        error_message: error.message,
        error_class: error.class.name,
        backtrace: error.backtrace&.join("\n") # Safe navigation operator
      }
      track_request('error', 'IVC ChampVA Forms - S3 UploadFile failure',
                    "#{STATS_KEY}.s3_upload.failure", # Consistent stats key
                    call_location: caller_locations.first, **additional_context)
    end

    ##
    # Logs UUID and S3 error message when supporting docs fail to reach S3.
    #
    # @param [String] form_uuid UUID of the form submission with failed uploads
    # @param [String] s3_err Error message received from a failed upload to S3
    def track_s3_upload_error(form_uuid, s3_err)
      additional_context = { form_uuid:, s3_err: }
      track_request('warn', "IVC ChampVa Forms - failed to upload all documents for submission: #{form_uuid}",
                    "#{STATS_KEY}.s3_upload_error",
                    call_location: caller_locations.first, **additional_context)
    end

    ##
    # Logs UUID and error message when an error occurs in pdf_stamper.rb
    #
    # @param [String] form_uuid UUID of the form submission with failed uploads
    # @param [String] err_message Error message received
    def track_pdf_stamper_error(form_uuid, err_message)
      additional_context = { form_uuid:, err_message: }
      track_request('warn', "IVC ChampVa Forms - an error occurred during pdf stamping: #{form_uuid}",
                    "#{STATS_KEY}.pdf_stamper_error",
                    call_location: caller_locations.first, **additional_context)
    end

    ##
    # Logs response from VES after submitting a form
    #
    # @param [String] form_uuid UUID of the form submission
    # @param [integer] status HTTP status code received from VES
    # @param [String] messages Full response received from VES
    def track_ves_response(form_uuid, status, messages)
      additional_context = { form_uuid:, status:, messages: }
      if status == 200
        track_request('info', "IVC ChampVa Forms - Successful submission to VES for form #{form_uuid}",
                      "#{STATS_KEY}.ves_response.success",
                      call_location: caller_locations.first, **additional_context)
      else
        track_request('error', "IVC ChampVa Forms - Error on submission to VES for form #{form_uuid}",
                      "#{STATS_KEY}.ves_response.failure",
                      call_location: caller_locations.first, **additional_context)
      end
    end
  end
end
