# frozen_string_literal: true

require 'decision_review_v1/utilities/form_4142_processor'
require 'decision_reviews/v1/helpers'
require 'decision_reviews/v1/constants'
require 'decision_reviews/v1/logging_utils'
require 'lighthouse/benefits_intake/service'

module DecisionReviews
  module V1
    # rubocop:disable Metrics/ModuleLength
    module SupplementalClaimServices
      include DecisionReviews::V1::Helpers
      include DecisionReviews::V1::LoggingUtils

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
          common_log_params = { key: :overall_claim_submission, form_id: '995', user_uuid: user.uuid,
                                downstream_system: 'Lighthouse' }
          response, bm = run_and_benchmark_if_enabled do
            perform :post, 'supplemental_claims', request_body, headers
          rescue => e
            log_formatted(**common_log_params.merge(error_log_params(e)))
            raise e
          end
          log_formatted(**common_log_params.merge(is_success: true, status_code: response.status, body: '[Redacted]'))
          raise_schema_error_unless_200_status response.status
          validate_against_schema json: response.body, schema: SC_CREATE_RESPONSE_SCHEMA,
                                  append_to_error_class: ' (SC_V1)'

          submission_info_message = parse_lighthouse_response_to_log_msg(data: response.body['data'], bm:)
          ::Rails.logger.info(submission_info_message)
          response
        end
      end

      ##
      # Creates a new 4142(a) PDF, and sends to Lighthouse
      #
      # @param appeal_submission_id
      # @param rejiggered_payload
      # @return [Faraday::Response]
      #
      def process_form4142_submission(appeal_submission_id:, rejiggered_payload:)
        with_monitoring_and_error_handling do
          response_container, bm = run_and_benchmark_if_enabled do
            submit_form4142(form_data: rejiggered_payload)
          end
          form4142_response, uuid = response_container

          if Flipper.enabled?(:decision_review_track_4142_submissions)
            save_form4142_submission(appeal_submission_id:, rejiggered_payload:, guid: uuid)
          end

          form4142_submission_info_message = parse_form412_response_to_log_msg(
            appeal_submission_id:, data: form4142_response, uuid:, bm:
          )
          ::Rails.logger.info(form4142_submission_info_message)
          form4142_response
        end
      end

      def save_form4142_submission(appeal_submission_id:, rejiggered_payload:, guid:)
        form_record = SecondaryAppealForm.new(
          form: rejiggered_payload.to_json,
          form_id: '21-4142',
          appeal_submission_id:,
          guid:
        )
        form_record.save!
      rescue => e
        ::Rails.logger.error({
                               error_message: e.message,
                               form_id: DecisionReviewV1::FORM4142_ID,
                               parent_form_id: DecisionReviewV1::SUPP_CLAIM_FORM_ID,
                               message: 'Supplemental Claim Form4142 Persistence Errored',
                               appeal_submission_id:,
                               lighthouse_submission: {
                                 id: guid
                               }
                             })
        raise e
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
          common_log_params = { key: :get_contestable_issues, form_id: '995', user_uuid: user.uuid,
                                upstream_system: 'Lighthouse' }
          begin
            response = perform :get, path, nil, headers
            log_formatted(**common_log_params.merge(is_success: true, status_code: response.status, body: '[Redacted]'))
          rescue => e
            # We can freely log Lighthouse's error responses because they do not include PII or PHI.
            # See https://developer.va.gov/explore/api/decision-reviews/docs?version=v1.
            log_formatted(**common_log_params.merge(error_log_params(e)))
            raise e
          end
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
      def get_supplemental_claim_upload_url(sc_uuid:, file_number:, user_uuid: nil, appeal_submission_upload_id: nil)
        common_log_params = {
          key: :get_lighthouse_evidence_upload_url,
          form_id: '995',
          user_uuid:,
          upstream_system: 'Lighthouse',
          downstream_system: 'Lighthouse',
          params: {
            sc_uuid:,
            appeal_submission_upload_id:
          }
        }
        with_monitoring_and_error_handling do
          response = perform :post, 'supplemental_claims/evidence_submissions', { sc_uuid: },
                             { 'X-VA-SSN' => file_number.to_s.strip.presence }
          log_formatted(**common_log_params.merge(is_success: true, status_code: response.status, body: response.body))
          response
        rescue => e
          # We can freely log Lighthouse's error responses because they do not include PII or PHI.
          # See https://developer.va.gov/explore/api/decision-reviews/docs?version=v2
          log_formatted(**common_log_params.merge(error_log_params(e)))
          raise e
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
      # rubocop:disable Metrics/MethodLength
      def put_supplemental_claim_upload(upload_url:, file_upload:, metadata_string:, user_uuid: nil,
                                        appeal_submission_upload_id: nil)
        tmpfile_name = construct_tmpfile_name(appeal_submission_upload_id, file_upload.filename)
        content_tmpfile = Tempfile.new([tmpfile_name, '.pdf'], encoding: file_upload.read.encoding)
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
        common_log_params = {
          key: :evidence_upload_to_lighthouse,
          form_id: '995',
          user_uuid:,
          downstream_system: 'Lighthouse',
          params: {
            upload_url:,
            appeal_submission_upload_id:
          }
        }
        with_monitoring_and_error_handling do
          response = perform :put, upload_url, params, { 'Content-Type' => 'multipart/form-data' }
          log_formatted(**common_log_params.merge(is_success: true, status_code: response.status, body: '[Redacted]'))
          response
        rescue => e
          # We can freely log Lighthouse's error responses because they do not include PII or PHI.
          # See https://developer.va.gov/explore/api/decision-reviews/docs?version=v2
          log_formatted(**common_log_params.merge(error_log_params(e)))
          raise e
        end
      ensure
        content_tmpfile.close
        content_tmpfile.unlink
        json_tmpfile.close
        json_tmpfile.unlink
      end
      # rubocop:enable Metrics/MethodLength

      ##
      # Returns all of the data associated with a specific Supplemental Claim Evidence Submission.
      #
      # @param guid [guid] supplemental Claim UUID Evidence Submission
      # @return [Faraday::Response]
      #
      def get_supplemental_claim_upload(guid:)
        with_monitoring_and_error_handling do
          perform :get, "supplemental_claims/evidence_submissions/#{guid}", nil
        end
      end

      ##
      # Returns an array of Job IDs (jids) of the queued evidence submission jobs
      #
      # @param sc_evidence [sc_evidence] supplemental Claim UUID Evidence Submission
      # @param appeal_submission_id
      # @return [String]
      #
      def queue_submit_evidence_uploads(sc_evidences, appeal_submission_id)
        sc_evidences.map do |upload|
          asu = AppealSubmissionUpload.create!(decision_review_evidence_attachment_guid: upload['confirmationCode'],
                                               appeal_submission_id:)

          DecisionReviews::SubmitUpload.perform_async(asu.id)
        end
      end

      ##
      # Returns a sidekiq Job ID (jid) of the queued form4142 generation
      # Sidekiq job is queued with the payload encrypted so there are no plaintext PII in the sidekiq job args.
      #
      # @param appeal_submission_id
      # @param rejiggered_payload
      # @param submitted_appeal_uuid
      # @return String
      #
      def queue_form4142(appeal_submission_id:, rejiggered_payload:, submitted_appeal_uuid:)
        DecisionReviews::Form4142Submit.perform_async(
          appeal_submission_id,
          payload_encrypted_string(rejiggered_payload),
          submitted_appeal_uuid
        )
      end

      private

      def submit_form4142(form_data:)
        processor = DecisionReviewV1::Processor::Form4142Processor.new(form_data:)
        service = BenefitsIntake::Service.new
        service.request_upload

        payload = {
          metadata: processor.request_body['metadata'],
          document: processor.request_body['document'],
          upload_url: service.location
        }

        response = service.perform_upload(**payload)

        [response, service.uuid]
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
