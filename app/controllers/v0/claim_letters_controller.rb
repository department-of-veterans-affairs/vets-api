# frozen_string_literal: true

require 'claim_letters/claim_letter_downloader'

module V0
  class ClaimLettersController < ApplicationController
    Raven.tags_context(feature: 'claim-letters')

    def index
      docs = service.get_letters

      render json: docs
    end

    def show
      document_id = CGI.unescape(params[:document_id])

      service.get_letter(document_id) do |data, mime_type, disposition, filename|
        send_data(data, type: mime_type, disposition:, filename:)
      end
    end

    private

    def service
      @service ||= ClaimStatusTool::ClaimLetterDownloader.new(@current_user)
    end
  end
end
