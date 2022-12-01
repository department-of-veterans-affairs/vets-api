# frozen_string_literal: true

module V1
  class SupplementalClaimsController < AppealsBaseControllerV1
    def show
      render json: decision_review_service.get_supplemental_claim(params[:id]).body
    rescue => e
      log_exception_to_personal_information_log(
        e, error_class: error_class(method: 'show', exception_class: e.class), id: params[:id]
      )
      raise
    end

    def create
      request_body_obj = request_body_hash.is_a?(String) ? JSON.parse(request_body_hash) : request_body_hash
      form4142 = request_body_obj.delete('form4142')
      sc_response = decision_review_service
                    .create_supplemental_claim(request_body: request_body_obj, user: @current_user)
      submitted_appeal_uuid = sc_response.body.dig('data', 'id')
      merged_response = {}
      merged_response[:data] = { body: sc_response.body, status: sc_response.status }
      unless form4142.nil?
        form4142_resp = decision_review_service.process_form4142_submission(
          request_body: request_body_obj, form4142: form4142, user: @current_user, response: sc_response
        )
        # We are not using this right now, but keeping it here incase we decide we want to return this
        # or do some action based on the central mail response, currently we do not.
        merged_response[:form4142] = { body: form4142_resp.body, status: form4142_resp.status }
      end

      clear_in_progress_form(submitted_appeal_uuid) unless submitted_appeal_uuid.nil?

      render json: sc_response.body, status: sc_response.status
    rescue => e
      handle_personal_info_error(e)
    end

    private

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
      ActiveRecord::Base.transaction do
        AppealSubmission.create!(user_uuid: @current_user.uuid, type_of_appeal: 'SC',
                                 submitted_appeal_uuid: submitted_appeal_uuid)
        # Clear in-progress form since submit was successful
        InProgressForm.form_for_user('20-0995', @current_user)&.destroy!
      end
    end

    def error_class(method:, exception_class:)
      "#{self.class.name}##{method} exception #{exception_class} (SC_V1)"
    end
  end
end
