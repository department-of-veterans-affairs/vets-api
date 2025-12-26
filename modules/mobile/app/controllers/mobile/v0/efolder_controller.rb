# frozen_string_literal: true

require 'lighthouse/benefits_documents/service'

module Mobile
  module V0
    class EfolderController < ApplicationController
      MAX_PAGE_SIZE = 100

      def index
        documents = if Flipper.enabled?(:efolder_use_lighthouse_benefits_documents_service, @current_user)
                      raw_documents = retrieve_all_documents
                      participant_documents_adapter.parse(raw_documents)
                    else
                      response = service.list_documents
                      efolder_adapter.parse(response)
                    end

        render json: Mobile::V0::EfolderSerializer.new(documents)
      end

      def download
        document = if Flipper.enabled?(:efolder_use_lighthouse_benefits_documents_service, @current_user)
                     # Backwards Compatibility: Delete {} brackets from document id as the
                     # benefit documents service doesn't support them
                     lighthouse_document_service
                       .participant_documents_download(document_uuid: params[:document_id].delete('{}'),
                                                       participant_id: @current_user.participant_id).body
                   else
                     service.get_document(params[:document_id])
                   end

        send_data(
          document,
          type: 'application/pdf',
          filename: file_name
        )
      end

      private

      def retrieve_all_documents
        all_documents = []
        page_number = 1
        has_more = true

        while has_more
          response = lighthouse_document_service.participant_documents_search(
            participant_id: @current_user.participant_id, page_number:, page_size: MAX_PAGE_SIZE
          ).body

          # Benefits Documents Service will pass back an empty data object if user has no documents
          break if response['data'].empty?

          documents = response.dig('data', 'documents')
          all_documents.concat(documents)

          if documents.size < MAX_PAGE_SIZE
            has_more = false
          else
            page_number += 1
          end
        end

        all_documents
      end

      def service
        ::Efolder::Service.new(@current_user)
      end

      def lighthouse_document_service
        @lighthouse_document_service ||= BenefitsDocuments::Service.new(@current_user)
      end

      def file_name
        params.require(:file_name)
      end

      def efolder_adapter
        Mobile::V0::Adapters::Efolder
      end

      def participant_documents_adapter
        Mobile::V0::Adapters::ParticipantDocuments
      end
    end
  end
end
