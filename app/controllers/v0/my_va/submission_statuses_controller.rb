# frozen_string_literal: true

require 'forms/submission_statuses/report'

module V0
  module MyVA
    class SubmissionStatusesController < ApplicationController
      service_tag 'form-submission-statuses'

      def show
        report = Forms::SubmissionStatuses::Report.new(
          user_account: @current_user.user_account,
          allowed_forms: forms_based_on_feature_toggle
        )

        result = report.run

        render json: serializable_from(result).to_json, status: status_from(result)
      end

      private

      def restricted_list_of_forms
        %w[
          20-10206
          20-10207
          21-0845
          21-0972
          21-10210
          21-4142
          21-4142a
          21P-0847
        ] + uploadable_forms
      end

      def uploadable_forms
        FormProfile::ALL_FORMS[:form_upload]
      end

      def serializable_from(result)
        hash = SubmissionStatusSerializer.new(result.submission_statuses).serializable_hash
        hash[:errors] = result.errors
        hash
      end

      def status_from(result)
        result.errors.present? ? 296 : 200
      end

      def forms_based_on_feature_toggle
        return nil if display_all_forms?

        restricted_list_of_forms
      end

      def display_all_forms?
        Flipper.enabled?(
          :my_va_display_all_lighthouse_benefits_intake_forms,
          @current_user
        )
      end
    end
  end
end
