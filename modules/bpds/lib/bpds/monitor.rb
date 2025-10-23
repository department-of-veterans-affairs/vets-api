# frozen_string_literal: true

require 'logging/monitor'

module BPDS
  # The Monitor class is responsible for tracking and logging various events related to the BPDS service.
  # It inherits from the ZeroSilentFailures::Monitor class and provides methods to track the beginning,
  # success, and failure of submission and JSON retrieval processes.
  class Monitor < Logging::Monitor
    # metric prefix
    STATSD_KEY_PREFIX = 'api.bpds_service'
    # allowed logging params
    ALLOWLIST = %w[
      bpds_uuid
      claim_id
      error
      errors
      lookup_service
      tags
    ].freeze

    def initialize
      super('bpds-service', allowlist: ALLOWLIST)
    end

    # Track submission request started
    #
    # @param claim_id [Integer] the SavedClaim id
    def track_submit_begun(claim_id)
      context = { claim_id: }
      track_request(
        :info,
        "BPDS::Service submit begun for saved_claim ##{claim_id}",
        "#{STATSD_KEY_PREFIX}.submit_json.begun",
        call_location: caller_locations.first,
        **context
      )
    end

    # Track submission successful
    #
    # @param claim_id [Integer] the SavedClaim id
    def track_submit_success(claim_id)
      context = { claim_id: }
      track_request(
        :info,
        "BPDS::Service submit succeeded for saved_claim ##{claim_id}",
        "#{STATSD_KEY_PREFIX}.submit_json.success",
        call_location: caller_locations.first,
        **context
      )
    end

    # Track submission request failure
    #
    # @param claim_id [Integer] the SavedClaim id
    # @param e [Error] the error which occurred
    def track_submit_failure(claim_id, e)
      context = {
        claim_id:,
        error: e&.message,
        errors: e.try(:errors)
      }
      track_request(
        :error,
        "BPDS::Service submit failed for saved_claim ##{claim_id}",
        "#{STATSD_KEY_PREFIX}.submit_json.failure",
        call_location: caller_locations.first,
        **context
      )
    end

    # Track get_json started
    #
    # @param bpds_uuid [UUID] the uuid generated for a submission
    def track_get_json_begun(bpds_uuid)
      context = { bpds_uuid: }
      track_request(
        :info,
        "BPDS::Service get_json begun for bpds_uuid ##{bpds_uuid}",
        "#{STATSD_KEY_PREFIX}.get_json_by_bpds_uuid.begun",
        call_location: caller_locations.first,
        **context
      )
    end

    # Track get_json successful
    #
    # @param bpds_uuid [UUID] the uuid generated for a submission
    def track_get_json_success(bpds_uuid)
      context = { bpds_uuid: }
      track_request(
        :info,
        "BPDS::Service get_json succeeded for bpds_uuid ##{bpds_uuid}",
        "#{STATSD_KEY_PREFIX}.get_json_by_bpds_uuid.success",
        call_location: caller_locations.first,
        **context
      )
    end

    # Track get_json failure
    #
    # @param bpds_uuid [UUID] the uuid generated for a submission
    def track_get_json_failure(bpds_uuid, e)
      context = {
        bpds_uuid:,
        error: e&.message,
        errors: e.try(:errors)
      }
      track_request(
        :error,
        "BPDS::Service get_json failed for bpds_uuid ##{bpds_uuid}",
        "#{STATSD_KEY_PREFIX}.get_json_by_bpds_uuid.failure",
        call_location: caller_locations.first,
        **context
      )
    end

    # Track user type for user identifier lookup for BPDS
    #
    # @param user_type [String] the user type of the user
    def track_get_user_identifier(user_type)
      context = { tags: ["user_type:#{user_type}"] }
      track_request(
        :info,
        "Pensions::V0::ClaimsController: #{user_type} user identifier lookup for BPDS",
        "#{STATSD_KEY_PREFIX}.get_participant_id",
        call_location: caller_locations.first,
        **context
      )
    end

    # Track result of user identifier lookup for BPDS when checking for participant id
    #
    # @param lookup_service [String] the service name
    # @param is_pid_present [Boolean] if the participant id is present in the response
    def track_get_user_identifier_result(lookup_service, is_pid_present)
      context = { lookup_service:, tags: ["pid_present:#{is_pid_present}"] }
      track_request(
        :info,
        "Pensions::V0::ClaimsController: #{lookup_service} service participant_id lookup result: #{is_pid_present}",
        "#{STATSD_KEY_PREFIX}.get_participant_id.#{lookup_service}.result",
        call_location: caller_locations.first,
        **context
      )
    end

    # Track result of user identifier lookup for BPDS when checking for file number
    #
    # @param is_file_number_present [Boolean] if the file number is present in the response
    def track_get_user_identifier_file_number_result(is_file_number_present)
      context = { tags: ["file_number_present:#{is_file_number_present}"] }
      track_request(
        :info,
        "Pensions::V0::ClaimsController: BGS service file_number lookup result: #{is_file_number_present}",
        "#{STATSD_KEY_PREFIX}.get_file_number.bgs.result",
        call_location: caller_locations.first,
        **context
      )
    end

    # Tracks and logs the event when a BPDS job is skipped due to a missing user identifier.
    #
    # @param claim_id [Integer, String] The ID of the saved claim for which the BPDS job was skipped.
    def track_skip_bpds_job(claim_id)
      context = { claim_id: }
      track_request(
        :info,
        "Pensions::V0::ClaimsController: No user identifier found, skipping BPDS job for saved_claim #{claim_id}",
        "#{STATSD_KEY_PREFIX}.job_skipped_missing_identifier",
        call_location: caller_locations.first,
        **context
      )
    end
  end
end
