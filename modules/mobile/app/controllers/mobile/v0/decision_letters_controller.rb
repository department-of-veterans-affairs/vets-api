# frozen_string_literal: true

require 'claim_letters/claim_letter_downloader'

module Mobile
  module V0
    class DecisionLettersController < ApplicationController
      before_action { authorize :bgs, :access? }

      def index
        response = service.get_letters
        list = if Flipper.enabled?(:cst_claim_letters_use_lighthouse_api_provider_mobile, @current_user)
                 lighthouse_decision_letters_adapter.parse(response)
               else
                 decision_letters_adapter.parse(response)
               end
        log_decision_letters(list) if Flipper.enabled?(:mobile_claims_log_decision_letter_sent)

        render json: Mobile::V0::DecisionLetterSerializer.new(list)
      rescue Common::Exceptions::ExternalServerInternalServerError => e
        translate_lighthouse_server_error!(e, '#index')
      end

      def download
        document_id = CGI.unescape(params[:document_id])
        service.get_letter(document_id) do |data, mime_type, disposition, filename|
          send_data(data, type: mime_type, disposition:, filename:)
        end
      rescue Common::Exceptions::ExternalServerInternalServerError => e
        translate_lighthouse_server_error!(e, '#download')
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

      def lighthouse_decision_letters_adapter
        Mobile::V0::Adapters::LighthouseDecisionLetters.new
      end

      def service
        if Flipper.enabled?(:cst_claim_letters_use_lighthouse_api_provider_mobile, @current_user)
          LighthouseClaimLettersProvider.new(@current_user)
        else
          ClaimStatusTool::ClaimLetterDownloader.new(@current_user)
        end
      end

      def translate_lighthouse_server_error!(error, source)
        if Flipper.enabled?(:cst_claim_letters_use_lighthouse_api_provider_mobile, @current_user)
          raise Common::Exceptions::BadGateway.new(detail: error.message, source: "DecisionLettersController#{source}")
        end

        raise
      end
    end
  end
end
