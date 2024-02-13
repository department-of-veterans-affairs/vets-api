# frozen_string_literal: true

require 'claim_letters/claim_letter_downloader'

module Mobile
  module V0
    class DecisionLettersController < ApplicationController
      before_action { authorize :bgs, :access? }

      def index
        response = service.get_letters
        list = decision_letters_adapter.parse(response)
        log_decision_letters(list) if Flipper.enabled?(:mobile_claims_log_decision_letter_sent)

        render json: Mobile::V0::DecisionLetterSerializer.new(list)
      end

      def download
        document_id = CGI.unescape(params[:document_id])

        service.get_letter(document_id) do |data, mime_type, disposition, filename|
          send_data(data, type: mime_type, disposition:, filename:)
        end
      end

      private

      def log_decision_letters(list)
        return nil if list.empty?

        Rails.logger.info('MOBILE DECISION LETTERS COUNT',
                          user_uuid: @current_user.uuid,
                          user_icn: @current_user.icn,
                          decision_letter_sent_count: list.count,
                          decision_letter_doc_type: list.map(&:doc_type),
                          filtered_out_doc_type27: Flipper.enabled?(:mobile_filter_doc_27_decision_letters_out))
      end

      def decision_letters_adapter
        Mobile::V0::Adapters::DecisionLetters.new
      end

      def service
        @service ||= ClaimStatusTool::ClaimLetterDownloader.new(@current_user, allowed_doctypes)
      end

      # 27: Board Of Appeals Decision Letter
      # 184: Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)
      # 339: Rating Decision Letter
      def allowed_doctypes
        doctypes = %w[184]
        doctypes << '27' unless Flipper.enabled?(:mobile_filter_doc_27_decision_letters_out)
        doctypes
      end
    end
  end
end
