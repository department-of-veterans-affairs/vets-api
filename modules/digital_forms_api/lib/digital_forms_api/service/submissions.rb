# frozen_string_literal: true

require 'digital_forms_api/service/base'
require 'digital_forms_api/service/request_schema'
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
        form_schema = schema_service.fetch(metadata[:formId] || metadata['formId'])
        request_schema = request_schema_service.fetch_submission_request_schema
        request = submission_validator.validate(payload:, metadata:, form_schema:, request_schema:)

        headers = {}

        perform :post, "submissions?dry-run=#{dry_run}", request, headers
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

      # @return [DigitalFormsApi::Service::RequestSchema] memoized request schema service instance
      def request_schema_service
        @request_schema_service ||= DigitalFormsApi::Service::RequestSchema.new
      end

      # end Submissions
    end

    # end Service
  end

  # end DigitalFormsApi
end
