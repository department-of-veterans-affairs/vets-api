# frozen_string_literal: true

require 'digital_forms_api/service/base'
require 'digital_forms_api/service/schema'
require 'digital_forms_api/validation/schema'

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
        validate_submission_payload(payload, metadata)

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

      # GET get a form submission
      def retrieve(submission_id)
        perform :get, "submissions/#{submission_id}", {}, {}
      end

      private

      # @see DigitalFormsApi::Service::Base#endpoint
      def endpoint
        'submissions'
      end

      def validate_submission_payload(payload, metadata)
        form_id = metadata[:formId]
        form_schema = DigitalFormsApi::Service::Schema.new.fetch(form_id)
        DigitalFormsApi::Validation.validate_against_schema(form_schema, payload)
      end

      # end Submissions
    end

    # end Service
  end

  # end DigitalFormsApi
end
