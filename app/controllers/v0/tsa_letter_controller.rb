# frozen_string_literal: true

require 'efolder/service'

module V0
  class TsaLetterController < ApplicationController
    service_tag 'tsa_letter'

    def index
      letter = service.get_tsa_letter
      render(json: letter)
    end

    def show
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
