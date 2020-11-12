# frozen_string_literal: true

require 'dmc/debt_letter_downloader'

module V0
  class DebtLettersController < ApplicationController
    def index
      render(json: service.list_letters)
    end

    def show
      send_data(
        service.get_letter(params[:id]),
        type: 'application/pdf',
        filename: service.file_name(params[:id])
      )
    end

    private

    def service
      @service ||= DMC::DebtLetterDownloader.new(@current_user)
    end
  end
end
