# frozen_string_literal: true

module MyHealth
  module V1
    class ThreadsController < SMController
      def index
        resource = fetch_folder_threads
        raise Common::Exceptions::RecordNotFound, params[:folder_id] if resource.blank?

        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: ThreadsSerializer,
               meta: resource.metadata
      end

      def move
        folder_id = params.require(:folder_id)
        client.post_move_thread(params[:id], folder_id)
        head :no_content
      end

      private

      def fetch_folder_threads
        puts "Fetching folder threads params #{params.inspect}"
        client.get_folder_threads(
          params[:folder_id].to_s,
          params[:page_size],
          params[:page_number],
          params[:sort_field],
          params[:sort_order],
          params[:requires_oh_messages].to_s
        )
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
