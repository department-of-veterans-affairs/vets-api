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

        result = apply_pdf_support(report.run)

        render json: serializable_from(result).to_json, status: status_from(result)
      end

      private

      def allowed_forms
        %w[20-10206 20-10207 21-0845 21-0972 21-10210 21-4142 21-4142a 21P-0847]
      end

      def apply_pdf_support(result)
        # add bool attr to determine if pdf downloads are supported for this submission
        if result.submission_statuses.is_a? Array
          result.submission_statuses.each do |elt|
            elt.pdf_support = SubmissionPdfUrlService.new(
              form_id: elt.form_type,
              submission_guid: elt.id
            ).supported?
          end
        end
        result
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
