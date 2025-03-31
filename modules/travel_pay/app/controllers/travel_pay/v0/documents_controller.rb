# frozen_string_literal: true

module TravelPay
  module V0
    class DocumentsController < ApplicationController
      def show
        begin
          document_summaries = documents_service.get_document_summaries(params[:claim_id])
          requested_doc = document_summaries.find do |doc|
            doc['documentId'] == params[:doc_id]
          end

          if requested_doc.nil?
            raise Common::Exceptions::ResourceNotFound, message: "Document not found. ID provided: #{params[:doc_id]}"
          end

          response = documents_service.download_document(params)
        rescue Faraday::Error => e
          TravelPay::ServiceError.raise_mapped_error(e)
        end

        send_data response.body,
                  filename: requested_doc['filename'],
                  type: requested_doc['mimetype'],
                  disposition: 'attachment'

        # OR maybe???:
        # send_data response.body, filename: response.headers['content-disposition']['filename'],
        #                          type: response.headers['content-type'], disposition: 'attachment'
      end

      private

      def auth_manager
        @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.client_number, @current_user)
      end

      def documents_service
        @documents_service ||= TravelPay::DocumentsService.new(auth_manager)
      end
    end
  end
end
