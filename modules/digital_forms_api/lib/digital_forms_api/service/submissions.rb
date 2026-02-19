# frozen_string_literal: true

require 'digital_forms_api/service/base'
require 'digital_forms_api/service/schema'
require 'digital_forms_api/validation/submission_request'

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
        form_schema = schema_service.fetch(metadata[:formId])
        request = submission_validator.validate(payload:, metadata:, form_schema:)

        headers = {}

        perform :post, "submissions?dry-run=#{dry_run}", request, headers
      end

      # POST submit form structured data and return a portable submission context.
      #
      # @param payload [Hash] the validated form data; @see SavedClaim.parsed_form
      # @param metadata [Hash] required fields in addition to payload
      # @param dry_run [Boolean] perform a dry run in which no action is taken except validation by the endpoint
      # @return [Hash] portable context for renderer/viewer integrations
      def submit_with_context(payload, metadata, dry_run: false)
        response = submit(payload, metadata, dry_run:)

        {
          submission_uuid: extract_submission_uuid(response),
          form_id: metadata[:formId],
          veteran_participant_id: metadata[:veteranId],
          claimant_participant_id: metadata[:claimantId] || metadata[:veteranId]
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

      # @return [DigitalFormsApi::Validation::SubmissionRequest] memoized validator instance
      def submission_validator
        @submission_validator ||= DigitalFormsApi::Validation::SubmissionRequest.new
      end

      # @return [DigitalFormsApi::Service::Schema] memoized schema service instance
      def schema_service
        @schema_service ||= DigitalFormsApi::Service::Schema.new
      end

      # @param response [#body] service response object
      # @return [String, nil] submission UUID from Digital Forms response
      def extract_submission_uuid(response)
        response.body.dig('submission', 'submissionId') || response.body.dig(:submission, :submissionId)
      end

      # end Submissions
    end

    # end Service
  end

  # end DigitalFormsApi
end
