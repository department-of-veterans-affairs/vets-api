# frozen_string_literal: true

require 'efolder/service'

module V0
  class TsaLetterController < ApplicationController
    service_tag 'tsa_letter'

    def index
      letters = service.list_tsa_letters
      render(json: TsaLetterSerializer.new(letters))
    end

    def show
      send_data(
        service.get_tsa_letter(params[:id]),
        type: 'application/pdf',
        filename: 'VETS Safe Travel Outreach Letter.pdf'
      )
    end

    private

    def service
      Efolder::Service.new(@current_user)
    end
  end
end
