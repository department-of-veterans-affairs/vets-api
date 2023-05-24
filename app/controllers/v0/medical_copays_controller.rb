# frozen_string_literal: true

module V0
  class MedicalCopaysController < ApplicationController
    before_action(except: :send_statement_notifications) { authorize :medical_copays, :access? }
    before_action(only: :send_statement_notifications) { authorize :medical_copays, :access_notifications? }

    skip_before_action :verify_authenticity_token, only: [:send_statement_notifications]
    skip_before_action :authenticate, only: [:send_statement_notifications]
    skip_after_action :set_csrf_header, only: [:send_statement_notifications]

    rescue_from ::MedicalCopays::VBS::Service::StatementNotFound, with: :render_not_found

    def index
      StatsD.increment('api.mcp.total')
      render json: vbs_service.get_copays
    end

    def show
      render json: vbs_service.get_copay_by_id(params[:id])
    end

    def get_pdf_statement_by_id
      send_data(
        vbs_service.get_pdf_statement_by_id(params[:statement_id]),
        type: 'application/pdf',
        filename: statement_params[:file_name]
      )
    end

    def send_statement_notifications
      vbs_service.send_statement_notifications(params[:statements])

      render json: { message: 'Parsing and sending notifications' }, status: :ok
    end

    private

    def statement_params
      params.permit(:file_name)
    end

    def vbs_service
      MedicalCopays::VBS::Service.build(user: current_user)
    end

    def render_not_found
      render json: nil, status: :not_found
    end
  end
end
