# frozen_string_literal: true

require 'decision_review_v1/utilities/constants'
require 'decision_review_v1/utilities/helpers'

module V1
  class SupplementalClaimsController < AppealsBaseControllerV1
    include DecisionReviewV1::Appeals::Helpers

    def show
      render json: decision_review_service.get_supplemental_claim(params[:id]).body
    rescue => e
      log_exception_to_personal_information_log(
        e, error_class: error_class(method: 'show', exception_class: e.class), id: params[:id]
      )
      raise
    end

    def create
      req_body_obj = request_body_hash.is_a?(String) ? JSON.parse(request_body_hash) : request_body_hash
      form4142 = req_body_obj.delete('form4142')
      sc_evidence = req_body_obj.delete('additionalDocuments')
      zip_from_frontend = req_body_obj.dig('data', 'attributes', 'veteran', 'address', 'zipCode5')
      sc_response = decision_review_service.create_supplemental_claim(request_body: req_body_obj, user: @current_user)
      submitted_appeal_uuid = sc_response.body.dig('data', 'id')
      unless submitted_appeal_uuid.nil?
        appeal_submission, _ipf_id = clear_in_progress_form(submitted_appeal_uuid, zip_from_frontend)
        appeal_submission_id = appeal_submission.id
        ::Rails.logger.info(post_create_log_msg(appeal_submission_id:, submitted_appeal_uuid:))
        if form4142.present?
          handle_4142(request_body: req_body_obj,
                      form4142:,
                      appeal_submission_id:, submitted_appeal_uuid:)
        end
        submit_evidence(sc_evidence, appeal_submission_id, submitted_appeal_uuid) if sc_evidence.present?
        render json: sc_response.body, status: sc_response.status
      end
    rescue => e
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

    def handle_4142(request_body:, form4142:, appeal_submission_id:, submitted_appeal_uuid:)
      rejiggered_payload = get_and_rejigger_required_info(request_body:, form4142:, user: @current_user)
      jid = decision_review_service.queue_form4142(appeal_submission_id:, rejiggered_payload:, submitted_appeal_uuid:)
      log_form4142_job_queued(appeal_submission_id, submitted_appeal_uuid, jid)
    end

    def log_form4142_job_queued(appeal_submission_id, submitted_appeal_uuid, jid)
      ::Rails.logger.info({
                            form_id: DecisionReviewV1::FORM4142_ID,
                            parent_form_id: DecisionReviewV1::SUPP_CLAIM_FORM_ID,
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
                            form_id: DecisionReviewV1::SUPP_CLAIM_FORM_ID,
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

    def clear_in_progress_form(submitted_appeal_uuid, backup_zip)
      ret = [nil, nil]
      ActiveRecord::Base.transaction do
        ret[0] = AppealSubmission.create! user_uuid: @current_user.uuid,
                                          user_account: @current_user.user_account,
                                          type_of_appeal: 'SC',
                                          submitted_appeal_uuid:,
                                          upload_metadata: DecisionReviewV1::Service.file_upload_metadata(
                                            @current_user, backup_zip
                                          )
        # Clear in-progress form since submit was successful
        ret[1] = InProgressForm.form_for_user('20-0995', @current_user)&.destroy!
      end
      ret
    end

    def error_class(method:, exception_class:)
      "#{self.class.name}##{method} exception #{exception_class} (SC_V1)"
    end
  end
end
