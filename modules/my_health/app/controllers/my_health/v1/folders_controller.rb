# frozen_string_literal: true

module MyHealth
  module V1
    class FoldersController < SMController
      def index
        resource = client.get_folders(@current_user.uuid, use_cache?)
        resource = resource.paginate(**pagination_params)

        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: MyHealth::V1::FolderSerializer,
               meta: resource.metadata
      end

      def show
        id = params[:id].try(:to_i)
        resource = client.get_folder(id)
        raise Common::Exceptions::RecordNotFound, id if resource.blank?

        render json: resource,
               serializer: MyHealth::V1::FolderSerializer,
               meta: resource.metadata
      end

      def create
        folder = Folder.new(create_folder_params)
        raise Common::Exceptions::ValidationErrors, folder unless folder.valid?

        resource = client.post_create_folder(folder.name)

        render json: resource,
               serializer: MyHealth::V1::FolderSerializer,
               meta: resource.metadata,
               status: :created
      end

      def update
        folder = Folder.new(create_folder_params)
        raise Common::Exceptions::ValidationErrors, folder unless folder.valid?

        resource = client.post_rename_folder(params[:id], folder.name)

        render json: resource,
               serializer: MyHealth::V1::FolderSerializer,
               meta: resource.metadata,
               status: :created
      end

      def destroy
        client.delete_folder(params[:id])
        head :no_content
      end

      def search
        message_search = MessageSearch.new(search_params)
        resource = client.post_search_folder(params[:id], params[:page], params[:per_page], message_search)

        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: MessagesSerializer,
               meta: resource.metadata
      end

      private

      def create_folder_params
        params.require(:folder).permit(:name)
      end

      def search_params
        params.permit(:exact_match, :sender, :subject, :category, :recipient, :from_date, :to_date, :message_id)
      end
    end
  end
end
