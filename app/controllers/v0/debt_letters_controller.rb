# frozen_string_literal: true

module V0
  class DebtLettersController < ApplicationController
    def index
      render(json: service.list_letters)
    end

    def show
      send_data(
        service.get_letter(params[:id]),
        type: 'application/pdf',
        filename: 'letter.pdf'
      )
    end

    private

    def service
      @service ||= Debts::LetterDownloader.new(@current_user.ssn)
    end
  end
end
