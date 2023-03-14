# frozen_string_literal: true

require 'decision_review_v1/utilities/form_4142_processor'
require 'decision_review_v1/utilities/helpers'
require 'decision_review_v1/utilities/constants'

module DecisionReviewV1
  module Appeals
    module SupplementalClaimServices
      include DecisionReviewV1::Appeals::Helpers

      ##
      # Returns all of the data associated with a specific Supplemental Claim.
      #
      # @param uuid [uuid] supplemental Claim UUID
      # @return [Faraday::Response]
      #
      def get_supplemental_claim(uuid)
        with_monitoring_and_error_handling do
          response = perform :get, "supplemental_claims/#{uuid}", nil
          raise_schema_error_unless_200_status response.status
          validate_against_schema json: response.body, schema: SC_SHOW_RESPONSE_SCHEMA,
                                  append_to_error_class: ' (SC_V1)'
          response
        end
      end

      ##
      # Creates a new Supplemental Claim
      #
      # @param request_body [JSON] JSON serialized version of a Supplemental Claim Form (20-0995)
      # @param user [User] Veteran who the form is in regard to
      # @return [Faraday::Response]
      #
      def create_supplemental_claim(request_body:, user:)
        with_monitoring_and_error_handling do
          request_body = request_body.to_json if request_body.is_a?(Hash)
          headers = create_supplemental_claims_headers(user)
          response, bm = run_and_benchmark_if_enabled do
            perform :post, 'supplemental_claims', request_body, headers
          end
          raise_schema_error_unless_200_status response.status
          validate_against_schema json: response.body, schema: SC_CREATE_RESPONSE_SCHEMA,
                                  append_to_error_class: ' (SC_V1)'

          submission_info_message = parse_lighthouse_response_to_log_msg(data: response.body['data'], bm: bm)
          ::Rails.logger.info(submission_info_message)
          response
        end
      end

      ##
      # Creates a new 4142(a) PDF, and sends to central mail
      #
      # @param request_body [JSON] JSON serialized version of a 4142/4142(a) form
      # @param user [User] Veteran who the form is in regard to
      # @param response [Faraday::Response] The response from creating the supplemental claim
      # @return [Faraday::Response]
      #
      def process_form4142_submission(request_body:, form4142:, user:, response:)
        appeal_submission_id = response.body['data']['id']
        with_monitoring_and_error_handling do
          form4142_response, bm = run_and_benchmark_if_enabled do
            new_body = get_and_rejigger_required_info(request_body: request_body, form4142: form4142, user: user)
            submit_form4142(form_data: new_body, response: response)
          end
          form4142_submission_info_message = parse_form412_response_to_log_msg(
            appeal_submission_id: appeal_submission_id, data: form4142_response, bm: bm
          )
          ::Rails.logger.info(form4142_submission_info_message)
          form4142_response
        end
      end

      ##
      # Returns all issues associated with a Veteran that have
      # been decided as of the receiptDate.
      # Not all issues returned are guaranteed to be eligible for appeal.
      #
      # @param user [User] Veteran who the form is in regard to
      # @param benefit_type [String] Type of benefit the decision review is for
      # @return [Faraday::Response]
      #
      def get_supplemental_claim_contestable_issues(user:, benefit_type:)
        with_monitoring_and_error_handling do
          path = "contestable_issues/supplemental_claims?benefit_type=#{benefit_type}"
          headers = get_contestable_issues_headers(user)
          response = perform :get, path, nil, headers
          raise_schema_error_unless_200_status response.status
          validate_against_schema(
            json: response.body,
            schema: GET_CONTESTABLE_ISSUES_RESPONSE_SCHEMA,
            append_to_error_class: ' (SC_V1)'
          )
          response
        end
      end

      ##
      # Get the url to upload supporting evidence for a Supplemental Claim
      #
      # @param sc_uuid [uuid] associated Supplemental Claim UUID
      # @param file_number [Integer] The file number or ssn
      # @return [Faraday::Response]
      #
      def get_supplemental_claim_upload_url(sc_uuid:, file_number:)
        with_monitoring_and_error_handling do
          perform :post, 'supplemental_claims/evidence_submissions', { sc_uuid: sc_uuid },
                  { 'X-VA-SSN' => file_number.to_s.strip.presence }
        end
      end

      ##
      # Upload supporting evidence for a Supplemental Claim
      #
      # @param upload_url [String] The url for the document to be uploaded
      # @param file_path [String] The file path for the document to be uploaded
      # @param metadata_string [Hash] additional data
      #
      # @return [Faraday::Response]
      #
      def put_supplemental_claim_upload(upload_url:, file_upload:, metadata_string:)
        content_tmpfile = Tempfile.new(file_upload.filename, encoding: file_upload.read.encoding)
        content_tmpfile.write(file_upload.read)
        content_tmpfile.rewind

        json_tmpfile = Tempfile.new('metadata.json', encoding: 'utf-8')
        json_tmpfile.write(metadata_string)
        json_tmpfile.rewind

        params = { metadata: Faraday::UploadIO.new(json_tmpfile.path, Mime[:json].to_s, 'metadata.json'),
                   content: Faraday::UploadIO.new(content_tmpfile.path, Mime[:pdf].to_s, file_upload.filename) }
        # when we upgrade to Faraday >1.0
        # params = { metadata: Faraday::FilePart.new(json_tmpfile, Mime[:json].to_s, 'metadata.json'),
        #            content: Faraday::FilePart.new(content_tmpfile, Mime[:pdf].to_s, file_upload.filename) }
        with_monitoring_and_error_handling do
          perform :put, upload_url, params, { 'Content-Type' => 'multipart/form-data' }
        end
      ensure
        content_tmpfile.close
        content_tmpfile.unlink
        json_tmpfile.close
        json_tmpfile.unlink
      end

      ##
      # Returns all of the data associated with a specific Supplemental Claim Evidence Submission.
      #
      # @param uuid [uuid] supplemental Claim UUID Evidence Submission
      # @return [Faraday::Response]
      #
      def get_supplemental_claim_upload(uuid:)
        with_monitoring_and_error_handling do
          perform :get, "supplemental_claims/evidence_submissions/#{uuid}", nil
        end
      end

      ##
      # Returns an array of Job IDs (jids) of the queued evidence submission jobs
      #
      # @param sc_evidence [sc_evidence] supplemental Claim UUID Evidence Submission
      # @return [String]
      #
      def queue_submit_evidence_uploads(sc_evidences, appeal_submission_id)
        sc_evidences.map do |upload|
          asu = AppealSubmissionUpload.create!(decision_review_evidence_attachment_guid: upload['confirmationCode'],
                                               appeal_submission_id: appeal_submission_id)

          DecisionReview::SubmitUpload.perform_async(asu.id)
        end
      end

      private

      def submit_form4142(form_data:, response:)
        processor = DecisionReviewV1::Processor::Form4142Processor.new(form_data: form_data, response: response)
        CentralMail::Service.new.upload(processor.request_body)
      end
    end
  end
end
