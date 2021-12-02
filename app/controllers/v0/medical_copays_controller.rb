# frozen_string_literal: true

module V0
  class MedicalCopaysController < ApplicationController
    before_action { authorize :medical_copays, :access? }

    def index
      StatsD.increment('api.mcp.total')
      render json: vbs_service.get_copays
    end

    def get_pdf_statement_by_id
      send_data(
        vbs_service.get_pdf_statement_by_id(params[:statement_id]),
        type: 'application/pdf',
        filename: statement_params[:file_name]
      )
    end

    private

    def statement_params
      params.permit(:file_name)
    end

    def vbs_service
      MedicalCopays::VBS::Service.build(user: current_user)
    end
  end
end
