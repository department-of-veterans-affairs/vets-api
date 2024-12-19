# frozen_string_literal: true

module DecisionReviews
  module V1
    class NoticeOfDisagreementsController < AppealsBaseController
      service_tag 'board-appeal'

      def show
        render json: decision_review_service.get_notice_of_disagreement(params[:id]).body
      rescue => e
        log_exception_to_personal_information_log(
          e, error_class: error_class(method: 'show', exception_class: e.class), id: params[:id]
        )
        raise
      end

      def create
        nod_response_body = AppealSubmission.submit_nod(
          current_user: @current_user,
          request_body_hash:,
          decision_review_service:,
          submit_upload_job:
        )

        render json: nod_response_body
      rescue => e
        ::Rails.logger.error(
          message: "Exception occurred while submitting Notice Of Disagreement: #{e.message}",
          backtrace: e.backtrace
        )
        handle_personal_info_error(e)
      end

      private

      def error_class(method:, exception_class:)
        "#{self.class.name}##{method} exception #{exception_class} (NOD_V1)"
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

      def submit_upload_job
        if Flipper.enabled? :decision_review_new_engine_submit_upload_job
          DecisionReviews::SubmitUpload
        else
          DecisionReview::SubmitUpload
        end
      end
    end
  end
end
