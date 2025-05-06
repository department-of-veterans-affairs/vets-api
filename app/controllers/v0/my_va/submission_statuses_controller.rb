# frozen_string_literal: true

require 'forms/submission_statuses/report'

module V0
  module MyVA
    class SubmissionStatusesController < ApplicationController
      service_tag 'form-submission-statuses'

      def show
        report = Forms::SubmissionStatuses::Report.new(
          user_account: @current_user.user_account,
          allowed_forms:
        )

        result = report.run

        render json: serializable_from(result).to_json, status: status_from(result)
      end

      private

      def allowed_forms
        %w[20-10206 20-10207 21-0845 21-0972 21-10210 21-4142 21-4142a 21P-0847] + uploadable_forms
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
    end
  end
end
