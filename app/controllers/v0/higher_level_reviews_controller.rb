# frozen_string_literal: true

module V0
  class HigherLevelReviewsController < AppealsBaseController
    def show
      render json: decision_review_service.get_higher_level_review(params[:id]).body
    rescue => e
      log_exception_to_personal_information_log(
        e, error_class: error_class(method: 'show', exception_class: e.class), id: params[:id]
      )
      raise
    end

    def create
      hlr_response_body = decision_review_service
                          .create_higher_level_review(request_body: request_body_hash, user: @current_user)
                          .body
      submitted_appeal_uuid = hlr_response_body.dig('data', 'id')
      AppealSubmission.create!(user_uuid: @current_user.uuid,
                               user_account: @current_user.user_account,
                               type_of_appeal: 'HLR',
                               submitted_appeal_uuid:)
      render json: hlr_response_body
    rescue => e
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

    private

    def error_class(method:, exception_class:)
      "#{self.class.name}##{method} exception #{exception_class} (HLR)"
    end
  end
end
