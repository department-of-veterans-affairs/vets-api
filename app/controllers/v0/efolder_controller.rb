# frozen_string_literal: true

module V0
  class EfolderController < ApplicationController
    def index
      render(json: service.list_documents)
    end

    def show
      send_data(
        service.get_document(params[:id]),
        type: 'application/pdf',
        filename: params[:filename]
      )
    end

    private

    def service
      Efolder::Service.new do |service|
        service.file_number = @current_user.ssn
        service.included_doc_types = params[:included_doc_types] if params[:included_doc_types].present?
      end
    end
  end
end
