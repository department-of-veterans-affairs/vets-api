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
      sc_response_body = decision_review_service
                         .create_supplemental_claim(request_body: request_body_hash, user: @current_user)
                         .body
      submitted_appeal_uuid = sc_response_body.dig('data', 'id')
      ActiveRecord::Base.transaction do
        AppealSubmission.create!(user_uuid: @current_user.uuid, type_of_appeal: 'SC',
                                 submitted_appeal_uuid: submitted_appeal_uuid)
        # Clear in-progress form since submit was successful
        InProgressForm.form_for_user('20-0995', current_user)&.destroy!
      end
      render json: sc_response_body
    rescue => e
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

    private

    def error_class(method:, exception_class:)
      "#{self.class.name}##{method} exception #{exception_class} (SC_V1)"
    end
  end
end
