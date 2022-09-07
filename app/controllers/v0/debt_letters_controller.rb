# frozen_string_literal: true

require 'debt_management_center/debt_letter_downloader'

module V0
  class DebtLettersController < ApplicationController
    before_action { authorize :debt_letters, :access? }

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
      @service ||= DebtManagementCenter::DebtLetterDownloader.new(@current_user)
    end
  end
end
