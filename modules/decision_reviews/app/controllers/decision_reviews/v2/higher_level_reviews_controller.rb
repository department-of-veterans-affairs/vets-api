# frozen_string_literal: true

require 'decision_reviews/saved_claim/service'
require_relative '../v1/appeals_base_controller'

module DecisionReviews
  module V2
    class HigherLevelReviewsController < V1::AppealsBaseController
      include DecisionReviews::SavedClaim::Service
      service_tag 'higher-level-review'

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
                            .create_higher_level_review(request_body: request_body_hash, user: @current_user,
                                                        version: 'V2')
                            .body
        submitted_appeal_uuid = hlr_response_body.dig('data', 'id')
        ActiveRecord::Base.transaction do
          AppealSubmission.create!(user_account: @current_user.user_account,
                                   type_of_appeal: 'HLR', submitted_appeal_uuid:)

          store_saved_claim(claim_class: ::SavedClaim::HigherLevelReview, form: request_body_hash.to_json,
                            guid: submitted_appeal_uuid)

          # Clear in-progress form since submit was successful
          InProgressForm.form_for_user('20-0996', current_user)&.destroy!
        end
        render json: hlr_response_body
      rescue => e
        ::Rails.logger.error(
          message: "Exception occurred while submitting Higher Level Review: #{e.message}",
          backtrace: e.backtrace
        )

        handle_personal_info_error(e)
      end

      private

      def error_class(method:, exception_class:)
        "#{self.class.name}##{method} exception #{exception_class} (HLR_V2)"
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
    end
  end
end
