# frozen_string_literal: true

module Mobile
  module V0
    class EfolderController < ApplicationController
      def index
        response = service.list_documents
        documents = efolder_adapter.parse(response)
        render json: Mobile::V0::EfolderSerializer.new(documents)
      end

      def download
        send_data(
          service.get_document(params[:document_id]),
          type: 'application/pdf',
          filename: file_name
        )
      end

      private

      def service
        ::Efolder::Service.new(@current_user)
      end

      def file_name
        params.require(:file_name)
      end

      def efolder_adapter
        Mobile::V0::Adapters::Efolder
      end
    end
  end
end
