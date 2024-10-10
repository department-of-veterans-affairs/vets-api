# frozen_string_literal: true

module Mobile
  module V0
    class EfolderController < ApplicationController
      def index
        response = service.list_documents
        documents = efolder_adapter.parse(response)
        render json: Mobile::V0::EfolderSerializer.new(documents)
      end

      private

      def service
        ::Efolder::Service.new(@current_user)
      end

      def efolder_adapter
        Mobile::V0::Adapters::Efolder.new
      end
    end
  end
end
