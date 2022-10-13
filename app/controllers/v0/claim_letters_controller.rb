# frozen_string_literal: true

require 'claim_letters/claim_letter_downloader'

module V0
  class ClaimLettersController < ApplicationController
    def index
      docs = service.list_letters
      render json: docs
    end

    def show
      service.get_letter(params[:document_id]) do |data, mime_type, disposition, filename|
        send_data(data, type: mime_type, disposition: disposition, filename: filename)
      end
    end

    private

    def service
      @service ||= ClaimStatusTool::ClaimLetterDownloader.new(@current_user.ssn)
    end
  end
end
