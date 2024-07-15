# frozen_string_literal: true

require 'forms/submission_statuses/report'

module V0
  module MyVA
    class SubmissionStatusesController < ApplicationController
      service_tag 'form-submission-statuses'
      before_action :controller_enabled?
      before_action { authorize :lighthouse, :access? }

      def show
        report = Forms::SubmissionStatuses::Report.new(@current_user.user_account)
        results = report.run

        render json: SubmissionStatusSerializer.new(results), status: :ok
      end

      private

      def controller_enabled?
        unless Flipper.enabled?(:my_va_form_submission_statuses, @current_user)
          raise Common::Exceptions::Forbidden, detail: 'Submission statuses are disabled.'
        end
      end
    end
  end
end
