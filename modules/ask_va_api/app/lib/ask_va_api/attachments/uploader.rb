# frozen_string_literal: true

module AskVAApi
  module Attachments
    class AttachmentsUploaderError < StandardError; end

    class Uploader
      MAX_PDF_SIZE_MB = 25
      ENDPOINT = 'attachment/new'

      attr_reader :params, :service

      def initialize(params)
        @params = params
        @service = Crm::Service.new(icn: nil)
      end

      def call
        validate_parameters!
        upload
      end

      private

      def upload
        response = service.call(endpoint: ENDPOINT, payload: params)
        parse_response(response)
      end

      def validate_parameters!
        raise AttachmentsUploaderError, 'Missing file content' unless params[:fileContent]

        unless valid_file_size?
          raise AttachmentsUploaderError,
                "File size exceeds the maximum limit of #{MAX_PDF_SIZE_MB} MB"
        end
        unless params[:inquiryId] || params[:correspondenceId]
          raise AttachmentsUploaderError,
                'Missing required ID (inquiryId or correspondenceId)'
        end
      end

      def valid_file_size?
        params[:fileContent].size <= MAX_PDF_SIZE_MB.megabytes
      end

      def parse_response(response)
        return response[:Data] if response.is_a?(Hash)

        error = JSON.parse(response.body, symbolize_names: true)
        raise(AttachmentsUploaderError, error)
      end
    end
  end
end
