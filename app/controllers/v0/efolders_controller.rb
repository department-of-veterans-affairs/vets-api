# frozen_string_literal: true

module V0
  class EFoldersController < ApplicationController
    def index
      render(json: service.list_documents)
    end

    def show
      send_data(
        service.get_document(params[:id]),
        type: 'application/pdf',
        filename: 'letter.pdf'
      )
    end

    private

    def service
      EFolder::Service.new do |service|
        service.file_number = @current_user.ssn
        service.excluded_documents = params[:excluded_documents]
      end
    end
  end
end
