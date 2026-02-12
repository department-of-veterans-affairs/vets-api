# frozen_string_literal: true

require 'digital_forms_api/service/base'

module DigitalFormsApi
  module Service
    # Submissions API
    class Submissions < Base
      # POST submit form structured data
      #
      # @param payload [Hash] the validated form data; @see SavedClaim.parsed_form
      # @param metadata [Hash] required fields in addition to payload
      # @option metadata [String] :formId the form identifier, eg. '21-686c'; required
      # @option metadata [String] :veteranId the participant id of the veteran; required
      # @option metadata [String] :claimantId the participant id of the claimant; default to veteranId
      # @option metadata [String] :epCode the ep code; required
      # @option metadata [String] :claimLabel the claim label; required
      # @param dry_run [Boolean] perform a dry run in which no action is taken except validation by the endpoint
      def submit(payload, metadata, dry_run: false)
        transformed = {
          claimantId: { identifierType: 'PARTICIPANTID', value: metadata[:claimantId] || metadata[:veteranId] },
          veteranId: { identifierType: 'PARTICIPANTID', value: metadata[:veteranId] },
          payload:
        }

        # TODO: validate the request structure (future)
        request = { envelope: metadata.merge(transformed) }

        headers = {}

        perform :post, "submissions?dry-run=#{dry_run}", request, headers
      end

      # POST submit then GET retrieve to resolve submission details
      #
      # Discovery helper that keeps all behavior scoped within digital_forms_api.
      # Existing `submit`/`retrieve` callers remain unchanged.
      #
      # @return [Hash]
      #   {
      #     submission_id: String | nil,
      #     claim_id: String | nil,
      #     participant_id: String | nil,
      #     resolved_user_uuid: String | nil,
      #     submit_response: Faraday::Env,
      #     retrieve_response: Faraday::Env | nil
      #   }
      def submit_and_resolve_uuid(payload, metadata, dry_run: false)
        submit_response = submit(payload, metadata, dry_run:)
        submission = extract_submission_hash(submit_response&.body)
        submission_id = submission['submissionId']

        retrieve_response = submission_id.present? ? retrieve(submission_id) : nil
        details = extract_submission_hash(retrieve_response&.body)

        {
          submission_id:,
          claim_id: details['claimId'] || submission['claimId'],
          participant_id: details['participantId'] || details['claimantId'] || submission['claimantId'],
          resolved_user_uuid: resolve_uuid_from_submission(details),
          submit_response:,
          retrieve_response:
        }
      end

      # GET get a form submission
      def retrieve(submission_id)
        perform :get, "submissions/#{submission_id}", {}, {}
      end

      private

      # @see DigitalFormsApi::Service::Base#endpoint
      def endpoint
        'submissions'
      end

      # Extracts the submission hash from the response body,
      # handling potential variations in structure.
      def extract_submission_hash(body)
        raw = body&.dig('submission')
        return {} unless raw.is_a?(Hash)

        raw.with_indifferent_access
      end

      # Resolves the UUID from the submission details,
      # handling potential variations in key names.
      def resolve_uuid_from_submission(details)
        details['uuid'] || details['userUuid'] || details['userUUID'] || details['resolvedUserUuid']
      end

      # end Submissions
    end

    # end Service
  end

  # end DigitalFormsApi
end
