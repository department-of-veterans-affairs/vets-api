# frozen_string_literal: true

module MyHealth
  module V1
    class ThreadsController < SMController
      def index
        resource = client.get_folder_threads(
          params[:folder_id].to_s,
          params[:page_size],
          params[:page_number],
          params[:sort_field],
          params[:sort_order]
        )

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
    end
  end
end
