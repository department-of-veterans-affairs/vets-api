# frozen_string_literal: true

require 'decision_reviews/v1//constants'
require 'decision_reviews/v1/helpers'
require 'decision_reviews/saved_claim/service'
module DecisionReviews
  module V1
    class SupplementalClaimsController < AppealsBaseController
      include DecisionReviews::V1::Helpers
      include DecisionReviews::SavedClaim::Service
      service_tag 'appeal-application'

      def show
        render json: decision_review_service.get_supplemental_claim(params[:id]).body
      rescue => e
        log_exception_to_personal_information_log(
          e, error_class: error_class(method: 'show', exception_class: e.class), id: params[:id]
        )
        raise
      end

      def create
        process_submission
      rescue => e
        ::Rails.logger.error(
          message: "Exception occurred while submitting Supplemental Claim: #{e.message}",
          backtrace: e.backtrace
        )
        handle_personal_info_error(e)
      end

      private

      def post_create_log_msg(appeal_submission_id:, submitted_appeal_uuid:)
        {
          message: 'Supplemental Claim Appeal Record Created',
          appeal_submission_id:,
          lighthouse_submission: {
            id: submitted_appeal_uuid
          }
        }
      end

      def handle_4142(request_body:, form4142:, appeal_submission_id:, submitted_appeal_uuid:) # rubocop:disable Naming/VariableNumber
        return if form4142.blank?

        rejiggered_payload = get_and_rejigger_required_info(request_body:, form4142:, user: @current_user)
        jid = decision_review_service.queue_form4142(appeal_submission_id:, rejiggered_payload:, submitted_appeal_uuid:)
        log_form4142_job_queued(appeal_submission_id, submitted_appeal_uuid, jid)
      end

      def log_form4142_job_queued(appeal_submission_id, submitted_appeal_uuid, jid)
        ::Rails.logger.info({
                              form_id: DecisionReviews::V1::FORM4142_ID,
                              parent_form_id: DecisionReviews::V1::SUPP_CLAIM_FORM_ID,
                              message: 'Supplemental Claim Form4142 queued.',
                              jid:,
                              appeal_submission_id:,
                              lighthouse_submission: {
                                id: submitted_appeal_uuid
                              }
                            })
      end

      def submit_evidence(sc_evidence, appeal_submission_id, submitted_appeal_uuid)
        # I know I could just use `appeal_submission.enqueue_uploads` here, but I want to return the jids to log, so
        # replicating instead. There is some duplicate code but I want them jids in the logs.
        jids = decision_review_service.queue_submit_evidence_uploads(sc_evidence, appeal_submission_id)
        ::Rails.logger.info({
                              form_id: DecisionReviews::V1::SUPP_CLAIM_FORM_ID,
                              message: 'Supplemental Claim Evidence jobs created.',
                              appeal_submission_id:,
                              lighthouse_submission: {
                                id: submitted_appeal_uuid
                              },
                              evidence_upload_job_ids: jids
                            })
      end

      def handle_personal_info_error(e)
        request = begin
          { body: request_body_hash }
        rescue
          request_body_debug_data
        end
        log_exception_to_personal_information_log(
          e, error_class: error_class(method: 'create', exception_class: e.class), request:
        )
        raise
      end

      def process_submission
        req_body_obj = request_body_hash.is_a?(String) ? JSON.parse(request_body_hash) : request_body_hash
        saved_claim_request_body = req_body_obj.to_json # serialize before request body is modified
        form4142 = req_body_obj.delete('form4142')
        sc_evidence = req_body_obj.delete('additionalDocuments')
        zip_from_frontend = req_body_obj.dig('data', 'attributes', 'veteran', 'address', 'zipCode5')

        sc_response = decision_review_service.create_supplemental_claim(request_body: req_body_obj, user: @current_user)
        submitted_appeal_uuid = sc_response.body.dig('data', 'id')

        ActiveRecord::Base.transaction do
          appeal_submission_id = create_appeal_submission(submitted_appeal_uuid, zip_from_frontend)
          handle_saved_claim(form: saved_claim_request_body, guid: submitted_appeal_uuid, form4142:)

          ::Rails.logger.info(post_create_log_msg(appeal_submission_id:, submitted_appeal_uuid:))
          handle_4142(request_body: req_body_obj, form4142:, appeal_submission_id:, submitted_appeal_uuid:)
          submit_evidence(sc_evidence, appeal_submission_id, submitted_appeal_uuid) if sc_evidence.present?

          # Only destroy InProgressForm after evidence upload step
          # so that we still have references if a fatal error occurs before this step
          clear_in_progress_form
        end
        render json: sc_response.body, status: sc_response.status
      end

      def create_appeal_submission(submitted_appeal_uuid, backup_zip)
        upload_metadata = DecisionReviews::V1::Service.file_upload_metadata(
          @current_user, backup_zip
        )
        create_params = {
          user_account: @current_user.user_account,
          type_of_appeal: 'SC',
          submitted_appeal_uuid:,
          upload_metadata:
        }
        appeal_submission = AppealSubmission.create!(create_params)
        appeal_submission.id
      end

      def handle_saved_claim(form:, guid:, form4142:)
        uploaded_forms = []
        uploaded_forms << '21-4142' if form4142.present?
        store_saved_claim(claim_class: ::SavedClaim::SupplementalClaim, form:, guid:, uploaded_forms:)
      end

      def clear_in_progress_form
        InProgressForm.form_for_user('20-0995', @current_user)&.destroy!
      end

      def error_class(method:, exception_class:)
        "#{self.class.name}##{method} exception #{exception_class} (SC_V1)"
      end
    end
  end
end
