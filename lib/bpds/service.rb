# frozen_string_literal: true

require 'common/client/base'
require 'bpds/configuration'
require 'bpds/jwt_encoder'

module BPDS
  ##
  # Proxy Service for the Benefits Processing Data Service (BPDS) API.
  # We are using it here to submit claims that cannot be auto-established,
  # via paper submission (electronic PDF submission to CMP)
  #
  class Service < Common::Client::Base
    configuration BPDS::Configuration

    attr_reader :monitor

    class FeatureDisabledError < StandardError; end

    # The Monitor class is responsible for tracking and logging various events related to the BPDS service.
    # It inherits from the ZeroSilentFailures::Monitor class and provides methods to track the beginning,
    # success, and failure of submission and JSON retrieval processes.
    class Monitor < ::ZeroSilentFailures::Monitor
      STATSD_KEY_PREFIX = 'api.bpds_service'

      def initialize
        super('bpds-service')
      end

      def track_submit_begun(saved_claim_id)
        additional_context = { saved_claim_id: }
        track_request(
          'info',
          "BPDS::Service submit begun for saved_claim ##{saved_claim_id}",
          "#{STATSD_KEY_PREFIX}.submit_json.begun",
          call_location: caller_locations.first,
          **additional_context
        )
      end

      def track_submit_success(saved_claim_id)
        additional_context = { saved_claim_id: }
        track_request(
          'info',
          "BPDS::Service submit succeeded for saved_claim ##{saved_claim_id}",
          "#{STATSD_KEY_PREFIX}.submit_json.success",
          call_location: caller_locations.first,
          **additional_context
        )
      end

      def track_submit_failure(saved_claim_id, e)
        additional_context = {
          saved_claim_id:,
          errors: e.try(:errors) || e&.message
        }
        track_request(
          'error',
          "BPDS::Service submit failed for saved_claim ##{saved_claim_id}",
          "#{STATSD_KEY_PREFIX}.submit_json.failure",
          call_location: caller_locations.first,
          **additional_context
        )
      end

      def track_get_json_begun(bpds_uuid)
        additional_context = { bpds_uuid: }
        track_request(
          'info',
          "BPDS::Service get_json begun for bpds_uuid ##{bpds_uuid}",
          "#{STATSD_KEY_PREFIX}.get_json_by_bpds_uuid.begun",
          call_location: caller_locations.first,
          **additional_context
        )
      end

      def track_get_json_success(bpds_uuid)
        additional_context = { bpds_uuid: }
        track_request(
          'info',
          "BPDS::Service get_json succeeded for bpds_uuid ##{bpds_uuid}",
          "#{STATSD_KEY_PREFIX}.get_json_by_bpds_uuid.success",
          call_location: caller_locations.first,
          **additional_context
        )
      end

      def track_get_json_failure(bpds_uuid, e)
        additional_context = {
          bpds_uuid:,
          errors: e.try(:errors) || e&.message
        }
        track_request(
          'error',
          "BPDS::Service get_json failed for bpds_uuid ##{bpds_uuid}",
          "#{STATSD_KEY_PREFIX}.get_json_by_bpds_uuid.failure",
          call_location: caller_locations.first,
          **additional_context
        )
      end
    end

    def initialize
      raise FeatureDisabledError, 'BPDS feature not enabled!' unless Flipper.enabled?(:bpds_service_enabled)

      @monitor = Monitor.new
      super
    end

    # Submits a JSON payload for a given claim.
    #
    # This method tracks the submission process, including success and failure events.
    # It constructs a payload from the claim, optionally includes a participant ID,
    # and performs a POST request with the payload. If an error occurs, it tracks the failure
    # and re-raises the exception.
    #
    # @param claim [SavedClaim] The claim object to be submitted.
    # @param participant_id [String, nil] The participant ID to be included in the payload (optional).
    # @return [String, nil] The response body from the submission, or nil if the claim is nil.
    # @raise [StandardError] If an error occurs during submission.
    def submit_json(claim, participant_id = nil)
      return nil if claim.nil?

      monitor.track_submit_begun(claim&.id)
      payload = default_payload(claim)
      payload.merge({ 'participantId' => participant_id }) if participant_id.present?
      response = perform(:post, '', payload.to_json, config.base_request_headers)
      # TODO: store the bpds_uuid in the future
      monitor.track_submit_success(claim&.id)
      response.body
    rescue => e
      monitor.track_submit_failure(claim&.id, e)
      raise e
    end

    # Retrieves JSON data by BPDS UUID.
    #
    # This method sends a GET request to the BPDS service using the provided UUID
    # and returns the response body as JSON. It also tracks the request's progress
    # and success or failure using the monitor.
    #
    # @param bpds_uuid [String] The UUID of the BPDS resource to retrieve.
    # @return [String] The JSON response body from the BPDS service.
    # @raise [StandardError] If the request fails, the error is tracked and re-raised.
    def get_json_by_bpds_uuid(bpds_uuid)
      monitor.track_get_json_begun(bpds_uuid)
      response = perform(:get, bpds_uuid.to_s, nil, config.base_request_headers)
      monitor.track_get_json_success(bpds_uuid)
      response.body
    rescue => e
      monitor.track_get_json_failure(bpds_uuid, e)
      raise e
    end

    private

    # Generates the default payload for a given claim.
    #
    # @param claim [Object] The claim object containing the form data.
    # @return [Hash, nil] A hash representing the default payload for the claim, or nil if the claim is nil.
    #
    # The returned hash has the following structure:
    # {
    #   'bpd' => {
    #     'sensitivityLevel' => Integer,
    #     'payloadNamespace' => String,
    #     'payload' => Hash
    #   }
    # }
    #
    # - 'sensitivityLevel' is currently set to 0. We may need to calculate this value in the future.
    # - 'payloadNamespace' is determined by the bpds_namespace method using the claim's form_id.
    # - 'payload' contains the parsed form data from the claim.
    def default_payload(claim)
      return nil if claim.nil?

      {
        'bpd' => {
          'sensitivityLevel' => 0,
          'payloadNamespace' => bpds_namespace(claim.form_id),
          'payload' => claim.parsed_form
        }
      }
    end

    ##
    # Generates a BPDS namespace string based on the form ID and expected schema version.
    #
    # The namespace is constructed in the format:
    # "urn::vets_api::<form_id>::<schema_version>"
    # where <schema_version>" is the month and year of the most recent version of the
    # JSON schema, 'test' by default
    #
    # @return [String] the BPDS namespace string
    def bpds_namespace(form_id)
      "urn:vets_api:#{form_id}:#{Settings.bpds.schema_version}"
    end
  end
end
