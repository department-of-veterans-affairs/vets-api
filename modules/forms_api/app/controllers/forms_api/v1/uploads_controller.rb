# frozen_string_literal: true

require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_info'

module FormsApi
  module V1
    class UploadsController < ApplicationController
      include CentralMail::Utilities
      skip_before_action :authenticate
      skip_after_action :set_csrf_header

      FORM_NUMBER_MAP = {
        '21-4142' => 'vba_21_4142',
        '26-4555' => 'vba_26_4555',
        '10-10D' => 'vha_10_10d'
      }.freeze

      def submit
        form_id = FORM_NUMBER_MAP[params[:form_number]]
        filler = FormsApi::PdfFiller.new(form_number: form_id, data: JSON.parse(params.to_json))

        file_path = filler.generate
        metadata = filler.metadata
        file_name = "#{form_id}.pdf"

        central_mail_service = CentralMail::Service.new
        filled_form = {
          'metadata' => metadata.to_json,
          'document' => filler.to_faraday_upload(file_path, file_name)
        }
        response = central_mail_service.upload(filled_form)

        Rails.logger.info("Forms api: #{params[:form_number]}, status: #{response.status}, uuid #{metadata['uuid']}")
        render json: { message: response.body, confirmation_number: metadata['uuid'] }, status: response.status
      rescue => e
        # scrubs all user-entered info from the error message
        param_hash = JSON.parse(params.to_json)
        remove_words(param_hash, e.message)
        raise e
      end

      def aggregate_words(hash)
        words = []
        hash.each_value do |value|
          case value
          when Hash
            words += aggregate_words(value)
          when String
            words += value.split
          end
        end
        words.uniq.sort_by(&:length).reverse
      end

      def remove_words(hash, message)
        words_to_remove = aggregate_words(hash)
        words_to_remove.each do |word|
          message.gsub!(word, '')
        end
        message
      end
    end
  end
end
