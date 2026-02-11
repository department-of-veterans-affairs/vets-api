# frozen_string_literal: true

module Mobile
  module V0
    class MedicalCopaysController < ApplicationController
      before_action { authorize :medical_copays, :access? }
      before_action :validate_feature_flag

      def index
        render json: service.get_copays
      end

      def show
        render json: service.get_copay_by_id(params[:id])
      end

      def download
        send_data(
          service.get_pdf_statement_by_id(params[:id]),
          type: 'application/pdf',
          filename: statement_params[:file_name]
        )
      rescue => e
        increment_pdf_statsd
        status = e.is_a?(::MedicalCopays::VBS::Service::StatementNotFound) ? :not_found : :internal_server_error
        render json: nil, status:
      end

      private

      def validate_feature_flag
        return if Flipper.enabled?(:mobile_medical_copays_enabled, @current_user)

        render json: {
          error: {
            code: 'FEATURE_NOT_AVAILABLE',
            message: 'This feature is not currently available'
          }
        }, status: :forbidden
      end

      def statement_params
        params.permit(:file_name)
      end

      def service
        @service ||= MedicalCopays::VBS::Service.build(user: @current_user)
      end

      def increment_pdf_statsd
        prefix = ::MedicalCopays::VBS::Service::STATSD_KEY_PREFIX
        StatsD.increment("#{prefix}.pdf.failure")
      end
    end
  end
end
