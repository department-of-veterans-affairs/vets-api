# frozen_string_literal: true

module Mobile
  module V0
    class MedicalCopaysController < ApplicationController
      before_action { authorize :medical_copays, :access? }

      rescue_from ::MedicalCopays::VBS::Service::StatementNotFound, with: :render_not_found

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
      end

      private

      def statement_params
        params.permit(:file_name)
      end

      def service
        @service ||= MedicalCopays::VBS::Service.build(user: @current_user)
      end

      def render_not_found
        render json: nil, status: :not_found
      end
    end
  end
end
