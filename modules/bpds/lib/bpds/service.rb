# frozen_string_literal: true

require 'common/client/base'
require 'bpds/configuration'
require 'bpds/jwt_generator'

module BPDS
  ##
  # Proxy Service for the Benefits Processing Data Service (BPDS) API.
  # We are using it here to submit claims that cannot be auto-established,
  # via paper submission (electronic PDF submission to CMP)
  #
  class Service < Common::Client::Base
    configuration BPDS::Configuration

    def initialize
      unless Flipper.enabled?(:bpds_service_enabled)
        raise Common::Exceptions::Forbidden,
              detail: 'BPDS feature not enabled!'
      end

      super
    end

    # Submits a JSON payload for a given claim.
    #
    # This method tracks the submission process, including success and failure events.
    # It constructs a payload from the claim, optionally includes a participant ID or file number,
    # and performs a POST request with the payload. If an error occurs, it tracks the failure
    # and re-raises the exception.
    #
    # @param claim [SavedClaim] The claim object to be submitted.
    # @param participant_id [String, nil] The participant ID to be included in the payload (optional).
    # @param file_number [String, nil] The file number to be included in the payload (optional).
    # @return [String] The response body from the submission
    # @raise [StandardError] If an error occurs during submission.
    def submit_json(claim, participant_id = nil, file_number = nil)
      payload = default_payload(claim, participant_id, file_number)
      response = perform(:post, '', payload.to_json, headers)

      response.body
    end

    # Retrieves JSON data by BPDS UUID.
    #
    # This method sends a GET request to the BPDS service using the provided UUID
    # and returns the response body as JSON.
    #
    # @param bpds_uuid [String] The UUID of the BPDS resource to retrieve.
    # @return [String] The JSON response body from the BPDS service.
    # @raise [StandardError] If the request fails, the error is tracked and re-raised.
    def get_json_by_bpds_uuid(bpds_uuid)
      response = perform(:get, bpds_uuid.to_s, nil, headers)

      response.body
    end

    private

    def headers
      { 'Authorization' => "Bearer #{BPDS::JwtGenerator.encode_jwt}" }
    end

    # Generates the default payload for a given claim.
    #
    # @param claim [Object] The claim object containing the form data.
    # @param participant_id [String, nil] The participant ID to be included in the payload (optional).
    # @param file_number [String, nil] The file number to be included in the payload (optional).
    # @return [Hash, nil] A hash representing the default payload for the claim, or nil if the claim is nil.
    #
    # The returned hash has the following structure:
    # {
    #   'bpd' => {
    #     'sensitivityLevel' => Integer,
    #     'payloadNamespace' => String,
    #     'participantId' => String, # Optional
    #     'fileNumber' => String, # Optional
    #     'payload' => Hash
    #   }
    # }
    #
    # - 'sensitivityLevel' is currently set to 0. We may need to calculate this value in the future.
    # - 'payloadNamespace' is determined by the bpds_namespace method using the claim's form_id.
    # - 'participantId' is included if provided, representing the user's participant ID.
    # - 'fileNumber' is included if provided, representing the user's file number.
    # - 'payload' contains the parsed form data from the claim.
    def default_payload(claim, participant_id = nil, file_number = nil)
      {
        'bpd' => {
          'sensitivityLevel' => 0,
          'payloadNamespace' => bpds_namespace(claim.form_id),
          'participantId' => participant_id,
          'fileNumber' => file_number,
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
