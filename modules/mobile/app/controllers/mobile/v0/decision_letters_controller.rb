# frozen_string_literal: true

require 'claim_letters/claim_letter_downloader'

module Mobile
  module V0
    class DecisionLettersController < ApplicationController
      before_action { authorize :bgs, :access? }

      def index
        response = service.get_letters
        render json: Mobile::V0::DecisionLetterSerializer.new(decision_letters_adapter.parse(response))
      end

      def download
        document_id = CGI.unescape(params[:document_id])

        service.get_letter(document_id) do |data, mime_type, disposition, filename|
          send_data(data, type: mime_type, disposition:, filename:)
        end
      end

      private

      def decision_letters_adapter
        Mobile::V0::Adapters::DecisionLetters.new
      end

      def service
        @service ||= ClaimStatusTool::ClaimLetterDownloader.new(@current_user)
      end
    end
  end
end
