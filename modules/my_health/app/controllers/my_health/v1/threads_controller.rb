# frozen_string_literal: true

module MyHealth
  module V1
    class ThreadsController < SMController
      def index
        begin 
          resource = client.get_folder_threads(
            params[:folder_id].to_s,
            params[:page_size],
            params[:page_number],
            params[:sort_field],
            params[:sort_order]
          )
        rescue => e
          error = e.errors.first
          # If there are no messages in the folder, MHV API returns a 400 error
          # We want to return an empty array in this case
          if error.status.to_i == 400 && error.detail == "No messages in the requested folder"
            resource = Common::Collection.new(MessageThread, data: [])
          else
            raise e
          end
        end
        

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
