# frozen_string_literal: true

module V1
  class SupplementalClaimsController < AppealsBaseControllerV1
    FORM4142_ID = '4142'
    SUPP_CLAIM_FORM_ID = '20-0995'

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
      sc_response = decision_review_service.create_supplemental_claim(request_body: req_body_obj, user: @current_user)
      submitted_appeal_uuid = sc_response.body.dig('data', 'id')
      unless submitted_appeal_uuid.nil?
        appeal_submission, _ipf_id = clear_in_progress_form(submitted_appeal_uuid)
        if form4142.present?
          handle_4142(request_body: req_body_obj,
                      form4142: form4142, response: sc_response, appeal_submission_id: appeal_submission.id,
                      submitted_appeal_uuid: submitted_appeal_uuid)
        end
        if sc_evidence.present?
          submit_evidence(sc_evidence, appeal_submission.id,
                          submitted_appeal_uuid)
        end
        render json: sc_response.body, status: sc_response.status
      end
    rescue => e
      handle_personal_info_error(e)
    end

    private

    def handle_4142(request_body:, form4142:, response:, appeal_submission_id:, submitted_appeal_uuid:)
      decision_review_service.process_form4142_submission(
        request_body: request_body, form4142: form4142, user: @current_user, response: response
      )
    rescue => e
      handle_form4142_error(e, appeal_submission_id, submitted_appeal_uuid)
    end

    def handle_form4142_error(e, appeal_submission_id, submitted_appeal_uuid)
      ::Rails.logger.error({
                             error_message: e.message,
                             form_id: FORM4142_ID,
                             parent_form_id: SUPP_CLAIM_FORM_ID,
                             message: 'Supplemental Claim Form4142 Could not be created or sent.',
                             appeal_submission_id: appeal_submission_id,
                             submitted_appeal_lighthouse_uuid: submitted_appeal_uuid
                           })
    end

    def submit_evidence(sc_evidence, appeal_submission_id, submitted_appeal_uuid)
      # I know I could just use `appeal_submission.enqueue_uploads` here, but I want to return the jids to log, so
      # replicating instead. There is some duplicate code but I want them jids in the logs.
      jids = decision_review_service.queue_submit_evidence_uploads(sc_evidence, appeal_submission_id)
      ::Rails.logger.info({
                            form_id: SUPP_CLAIM_FORM_ID,
                            message: 'Supplemental Claim Evidence jobs created.',
                            appeal_submission_id: appeal_submission_id,
                            submitted_appeal_lighthouse_uuid: submitted_appeal_uuid,
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
        e, error_class: error_class(method: 'create', exception_class: e.class), request: request
      )
      raise
    end

    def clear_in_progress_form(submitted_appeal_uuid)
      ret = [nil, nil]
      ActiveRecord::Base.transaction do
        ret[0] = AppealSubmission.create! user_uuid: @current_user.uuid,
                                          user_account: @current_user.user_account,
                                          type_of_appeal: 'SC',
                                          submitted_appeal_uuid: submitted_appeal_uuid,
                                          upload_metadata: DecisionReviewV1::Service.file_upload_metadata(@current_user)
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
