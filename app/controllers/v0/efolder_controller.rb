# frozen_string_literal: true

require 'efolder/service'

module V0
  class EfolderController < ApplicationController
    service_tag 'efolder'

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

    def get_tsa_letter_metadata
      letter = service.get_tsa_letter
      render(json: letter)
    end

    def download_tsa_letter
      send_data(
        service.download_tsa_letter(params[:id]),
        type: 'application/pdf',
        filename: params[:filename]
      )
    end

    private

    def service
      Efolder::Service.new(@current_user)
    end
  end
end
