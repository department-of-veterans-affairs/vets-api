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

    ##
    # Logs when an MPI profile is successfully found
    #
    # @param [String] person_type Type of person ('applicant' or 'veteran')
    def track_mpi_profile_found(person_type)
      additional_context = {
        person_type:
      }
      track_request('info', "IVC ChampVA Forms - MPI profile found for #{person_type}",
                    "#{STATS_KEY}.mpi_profile.found",
                    call_location: caller_locations.first, **additional_context)
    end

    ##
    # Logs when an MPI profile is not found
    #
    # @param [String] person_type Type of person ('applicant' or 'veteran')
    # @param [String] error_type Optional error type/class for debugging (no PII)
    def track_mpi_profile_not_found(person_type, error_type = nil)
      additional_context = {
        person_type:,
        error_type:
      }.compact
      track_request('warn', "IVC ChampVA Forms - MPI profile not found for #{person_type}",
                    "#{STATS_KEY}.mpi_profile.not_found",
                    call_location: caller_locations.first, **additional_context)
    end

    ##
    # Logs response from LLM processor after submitting a document
    #
    # @param [String] transaction_uuid UUID of the processing transaction
    # @param [Integer] status HTTP status code received from LLM processor
    # @param [String] messages Full response received from LLM processor
    def track_llm_processor_response(transaction_uuid, status, messages)
      additional_context = { transaction_uuid:, status:, messages: }
      if status == 200
        track_request('info',
                      "IVC ChampVa Forms - Successful submission to LLM processor for transaction #{transaction_uuid}",
                      "#{STATS_KEY}.llm_processor_response.success",
                      call_location: caller_locations.first, **additional_context)
      else
        track_request('error',
                      "IVC ChampVa Forms - Error on submission to LLM processor for transaction #{transaction_uuid}",
                      "#{STATS_KEY}.llm_processor_response.failure",
                      call_location: caller_locations.first, **additional_context)
      end
    end

    ##
    # Logs when an MPI service call fails
    #
    # @param [String] person_type Type of person ('applicant' or 'veteran')
    # @param [String] error_type Optional error type/class for debugging (no PII)
    def track_mpi_service_error(person_type, error_type = nil)
      additional_context = {
        person_type:,
        error_type:
      }.compact
      track_request('error', "IVC ChampVA Forms - MPI service error for #{person_type}",
                    "#{STATS_KEY}.mpi_profile.error",
                    call_location: caller_locations.first, **additional_context)
    end

    ##
    # Tracks sample size for experiments by incrementing a counter
    #
    # @param [String] experiment_name Name of the experiment (e.g., 'llm_validator', 'ocr_validator')
    # @param [String] uuid Document UUID for tracking context
    def track_experiment_sample_size(experiment_name, uuid)
      additional_context = { experiment_name:, uuid: }
      StatsD.increment("#{STATS_KEY}.experiment.#{experiment_name}.sample_size",
                       tags: ["service:#{service}", "experiment:#{experiment_name}"])
      track_request('info', "IVC ChampVA Experiment - #{experiment_name} sample processed for #{uuid}",
                    "#{STATS_KEY}.experiment.#{experiment_name}.sample_processed",
                    call_location: caller_locations.first, **additional_context)
    end

    ##
    # Tracks processing time for experiments as a histogram metric
    #
    # @param [String] experiment_name Name of the experiment (e.g., 'llm_validator', 'ocr_validator')
    # @param [Float] duration_ms Processing time in milliseconds
    # @param [String] uuid Document UUID for tracking context
    def track_experiment_processing_time(experiment_name, duration_ms, uuid)
      additional_context = { experiment_name:, duration_ms:, uuid: }
      StatsD.histogram("#{STATS_KEY}.experiment.#{experiment_name}.processing_time",
                       duration_ms,
                       tags: ["service:#{service}", "experiment:#{experiment_name}"])
      track_request('info', "IVC ChampVA Experiment - #{experiment_name} processed #{uuid} in #{duration_ms}ms",
                    "#{STATS_KEY}.experiment.#{experiment_name}.processing_completed",
                    call_location: caller_locations.first, **additional_context)
    end

    ##
    # Generic method to track experiment metrics as gauge values
    #
    # @param [String] experiment_name Name of the experiment (e.g., 'llm_validator', 'ocr_validator')
    # @param [String] field_name Name of the metric field (e.g., 'confidence', 'validity', 'missing_fields_count')
    # @param [Numeric, Boolean] value The value to track (Boolean values converted to 1/0)
    # @param [String] uuid Document UUID for tracking context
    def track_experiment_metric(experiment_name, field_name, value, uuid)
      # Convert boolean values to numeric for StatsD
      metric_value = if value.is_a?(TrueClass)
                       1
                     else
                       (value.is_a?(FalseClass) ? 0 : value)
                     end

      additional_context = { experiment_name:, field_name:, value:, uuid: }
      StatsD.gauge("#{STATS_KEY}.experiment.#{experiment_name}.#{field_name}",
                   metric_value,
                   tags: ["service:#{service}", "experiment:#{experiment_name}"])
      track_request('info', "IVC ChampVA Experiment - #{experiment_name} #{field_name} #{value} for #{uuid}",
                    "#{STATS_KEY}.experiment.#{experiment_name}.#{field_name}_tracked",
                    call_location: caller_locations.first, **additional_context)
    end

    ##
    # Tracks experiment errors by incrementing an error counter
    #
    # @param [String] experiment_name Name of the experiment (e.g., 'llm_validator', 'ocr_validator')
    # @param [String] error_type The type/class of error that occurred
    # @param [String] uuid Document UUID for tracking context
    # @param [String] error_message Optional error message (will be filtered for PII)
    def track_experiment_error(experiment_name, error_type, uuid, error_message = nil)
      additional_context = { experiment_name:, error_type:, uuid:, error_message: }.compact
      StatsD.increment("#{STATS_KEY}.experiment.#{experiment_name}.error",
                       tags: ["service:#{service}", "experiment:#{experiment_name}", "error_type:#{error_type}"])
      track_request('error', "IVC ChampVA Experiment - #{experiment_name} error #{error_type} for #{uuid}",
                    "#{STATS_KEY}.experiment.#{experiment_name}.error_tracked",
                    call_location: caller_locations.first, **additional_context)
    end

    ##
    # Logs UUID and error message when document merging fails
    #
    # @param [String] form_uuid UUID of the form submission with failed merge
    # @param [String] error_message Error message from the merge failure
    def track_merge_error(form_uuid, error_message)
      additional_context = { form_uuid:, error_message: }
      track_request('warn', "IVC ChampVa Forms - document merge failed for submission: #{form_uuid}",
                    "#{STATS_KEY}.merge_error",
                    call_location: caller_locations.first, **additional_context)
    end
  end
end
