# frozen_string_literal: true

require 'efolder/service'

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
      Efolder::Service.new(@current_user)
    end
  end
end
