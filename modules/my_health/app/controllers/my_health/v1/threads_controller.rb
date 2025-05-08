# frozen_string_literal: true

require 'vets/collection'

module MyHealth
  module V1
    class ThreadsController < SMController
      def index
        resource = fetch_folder_threads
        raise Common::Exceptions::RecordNotFound, params[:folder_id] if resource.blank?

        options = { meta: resource.metadata }
        render json: ThreadsSerializer.new(resource.records, options)
      end

      def move
        folder_id = params.require(:folder_id)
        client.post_move_thread(params[:id], folder_id)
        head :no_content
      end

      private

      def fetch_folder_threads
        options = {
          page_size: params[:page_size],
          page_number: params[:page_number],
          sort_field: params[:sort_field],
          sort_order: params[:sort_order],
          requires_oh_messages: params[:requires_oh_messages].to_s
        }
        client.get_folder_threads(params[:folder_id].to_s, options)
      rescue => e
        handle_error(e)
      end

      def handle_error(e)
        error = e.errors.first
        if error.status.to_i == 400 && error.detail == 'No messages in the requested folder'
          Vets::Collection.new([], MessageThread)
        else
          raise e
        end
      end
    end
  end
end
