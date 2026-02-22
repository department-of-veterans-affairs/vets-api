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

      # submit and include parsed submission uuid details from the synchronous response
      #
      # @return [Hash]
      # @option return [Faraday::Response] :response
      # @option return [String, nil] :submission_uuid
      # @option return [Boolean] :synchronous
      def submit_with_uuid(payload, metadata, dry_run: false)
        response = submit(payload, metadata, dry_run:)
        body = response&.body
        submission_uuid = if body.is_a?(Hash)
                            body.dig('submission', 'submissionId') || body.dig(:submission, :submissionId)
                          end
        submission_uuid = nil if submission_uuid.respond_to?(:blank?) && submission_uuid.blank?
        successful_response = response&.try(:success?) || response&.status.to_i.between?(200, 299)

        {
          response:,
          submission_uuid:,
          synchronous: successful_response && submission_uuid.present?
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

      # end Submissions
    end

    # end Service
  end

  # end DigitalFormsApi
end
