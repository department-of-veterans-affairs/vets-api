# frozen_string_literal: true

module MyHealth
  module V1
    class ThreadsController < SMController
      def index
        resource = fetch_folder_threads
        raise Common::Exceptions::RecordNotFound, params[:folder_id] if resource.blank?

        options = { meta: resource.metadata }
        render json: ThreadsSerializer.new(resource.data, options)
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
          sort_order: params[:sort_order]
        }
        client.get_folder_threads(params[:folder_id].to_s, options)
      rescue => e
        handle_error(e)
      end

      def handle_error(e)
        error = e.errors.first
        if error.status.to_i == 400 && error.detail == 'No messages in the requested folder'
          Common::Collection.new(
            MessageThread, data: []
          )
        else
          raise e
        end
      end
    end
  end
end
