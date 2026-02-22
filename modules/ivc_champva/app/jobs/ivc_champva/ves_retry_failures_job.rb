# frozen_string_literal: true

require 'sidekiq'
require 'ves_api/client'
require 'json'

# This job grabs all failed VES submissions and retries them
# After 5 attempts, it will trigger a slack notification
module IvcChampva
  class VesRetryFailuresJob
    include Sidekiq::Job

    def perform
      return unless Flipper.enabled?(:champva_ves_retry_failures_job)

      # Get all failed VES submissions
      failed_ves_submissions = IvcChampvaForm.where.not(ves_status: [nil, 'ok'])

      return unless failed_ves_submissions.any?

      # Send the count of forms to DataDog
      StatsD.gauge('ivc_champva.ves_submission_failures.count', failed_ves_submissions.count)

      # Retry the failed submissions
      failed_ves_submissions.each do |record|
        begin # rubocop:disable Style/RedundantBegin
          # for all records older than 5 hours, increment the StatsD counter and don't retry
          # if the failure is less than 5 hours old, retry the submission
          next unless can_retry?(record)

          if record.created_at < 5.hours.ago
            StatsD.increment('ivc_champva.ves_submission_failures', tags: ["id:#{record.form_uuid}"])
          else
            resubmit_ves_request(record)
          end
        rescue => e
          Rails.logger.error("Error resubmitting VES request: #{e.message}")
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    end

    ##
    # Determines if a record can be retried based on available data.
    # Prefers request_json (new approach) but falls back to ves_request_data (legacy).
    #
    # @param record [IvcChampvaForm] the form record to check
    # @return [Boolean] true if the record has data to retry with
    def can_retry?(record)
      return true if record.request_json.present? || record.ves_request_data.present?

      Rails.logger.warn("Skipping VES retry for #{record.form_uuid}: no request_json or ves_request_data available")
      false
    end

    ##
    # Resubmits a failed VES request.
    # Uses request_json to rebuild the VES request if available, otherwise falls back to ves_request_data.
    #
    # @param record [IvcChampvaForm] the form record to resubmit
    def resubmit_ves_request(record)
      ves_client = IvcChampva::VesApi::Client.new

      if record.request_json.present?
        resubmit_from_request_json(ves_client, record)
      else
        resubmit_from_ves_request_data(ves_client, record)
      end
    end

    private

    ##
    # Resubmits using the new request_json approach.
    # Rebuilds the VES request(s) using VesDataFormatter and submits them.
    #
    # @param ves_client [IvcChampva::VesApi::Client] the VES API client
    # @param record [IvcChampvaForm] the form record to resubmit
    def resubmit_from_request_json(ves_client, record)
      parsed_form_data = JSON.parse(record.request_json)
      form_number = parsed_form_data['form_number']
      ves_requests = build_ves_requests(parsed_form_data, form_number)

      if ves_requests.blank?
        Rails.logger.warn("No VES requests built for #{record.form_uuid}")
        return
      end

      all_successful, last_response = submit_all_ves_requests(ves_client, ves_requests, form_number, record)
      finalize_record_status(record, ves_requests, all_successful, last_response)
    end

    ##
    # Submits all VES requests and tracks success status.
    #
    # @return [Array<Boolean, Faraday::Response>] tuple of all_successful flag and last response
    def submit_all_ves_requests(ves_client, ves_requests, form_number, record)
      all_successful = true
      last_response = nil

      ves_requests.each do |ves_request|
        ves_request.transaction_uuid = SecureRandom.uuid
        last_response = send_to_ves_by_form_type(ves_client, ves_request, form_number)
        all_successful = false unless last_response&.status == 200
        submit_subforms(ves_client, ves_request, record) if ves_request.respond_to?(:subforms?) && ves_request.subforms?
      rescue => e
        Rails.logger.error "Error submitting VES request for #{record.form_uuid}: #{e.message}"
        all_successful = false
      end

      [all_successful, last_response]
    end

    ##
    # Updates record status based on submission results.
    def finalize_record_status(record, ves_requests, all_successful, last_response)
      if !all_successful && ves_requests.size > 1
        record.update(ves_status: 'partial_failure')
      elsif last_response
        update_record_status(record, last_response)
      end
    end

    ##
    # Resubmits using the legacy ves_request_data approach.
    # Parses the stored JSON and resubmits directly to VES.
    #
    # @param ves_client [IvcChampva::VesApi::Client] the VES API client
    # @param record [IvcChampvaForm] the form record to resubmit
    def resubmit_from_ves_request_data(ves_client, record)
      ves_request = JSON.parse(record.ves_request_data)

      # Generate a new transaction UUID
      ves_request['transaction_uuid'] = SecureRandom.uuid

      response = ves_client.submit_1010d(ves_request['transaction_uuid'], 'fake-user', ves_request)

      update_record_status(record, response)
    end

    ##
    # Builds the appropriate VES request(s) based on form number.
    # Always returns an array for consistent handling.
    #
    # @param parsed_form_data [Hash] the parsed form data
    # @param form_number [String] the form number (e.g., '10-10D', '10-10D-EXTENDED', '10-7959C')
    # @return [Array] array of VES request objects, or empty array if unsupported
    def build_ves_requests(parsed_form_data, form_number)
      case form_number
      when '10-10D'
        [VesDataFormatter.format_for_request(parsed_form_data)]
      when '10-10D-EXTENDED'
        [VesDataFormatter.format_for_extended_request(parsed_form_data)]
      when '10-7959C'
        VesDataFormatter.format_for_ohi_request(parsed_form_data) || []
      else
        Rails.logger.warn("Unsupported form_number for VES retry: #{form_number}")
        []
      end
    end

    ##
    # Routes the VES submission to the appropriate client method based on form number.
    #
    # @param ves_client [IvcChampva::VesApi::Client] the VES API client
    # @param ves_request [Object] the VES request object
    # @param form_number [String] the form number
    # @return [Faraday::Response] the VES API response
    def send_to_ves_by_form_type(ves_client, ves_request, form_number)
      case form_number
      when '10-10D', '10-10D-EXTENDED'
        ves_client.submit_1010d(ves_request.transaction_uuid, 'fake-user', ves_request)
      when '10-7959C'
        ves_client.submit_7959c(ves_request.transaction_uuid, 'fake-user', ves_request)
      else
        raise ArgumentError, "Unknown form type for VES submission: #{form_number}"
      end
    end

    ##
    # Submits subforms attached to the primary VES request.
    #
    # @param ves_client [IvcChampva::VesApi::Client] the VES API client
    # @param ves_request [IvcChampva::VesRequest] the primary VES request with subforms
    # @param record [IvcChampvaForm] the form record (for logging)
    def submit_subforms(ves_client, ves_request, record)
      ves_request.subforms.each do |subform|
        subform[:request].transaction_uuid = SecureRandom.uuid
        send_to_ves_by_form_type(ves_client, subform[:request], '10-7959C')
      rescue => e
        Rails.logger.error "Error submitting VES subform for #{record.form_uuid}: #{e.message}"
      end
    end

    ##
    # Updates the record status based on the VES response.
    #
    # @param record [IvcChampvaForm] the form record to update
    # @param response [Faraday::Response] the VES API response
    def update_record_status(record, response)
      ves_status = response.status == 200 ? 'ok' : response.body
      record.update(ves_status:)
    end
  end
end
