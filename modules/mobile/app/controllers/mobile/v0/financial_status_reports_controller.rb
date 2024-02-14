# frozen_string_literal: true

module Mobile
  module V0
    class FinancialStatusReportsController < ApplicationController
      before_action { authorize :debt, :access? }

      def download
        send_data(
          service.get_pdf,
          type: 'application/pdf',
          filename: 'VA Form 5655 - Submitted',
          disposition: 'attachment'
        )
      rescue ::DebtsApi::V0::FinancialStatusReportService::FSRNotFoundInRedis
        render json: nil, status: :not_found
      end

      private

      def service
        @service ||= DebtsApi::V0::FinancialStatusReportService.new(@current_user)
      end
    end
  end
end
