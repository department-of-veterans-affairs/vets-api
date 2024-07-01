# frozen_string_literal: true

require_relative '../../concerns/my_health/json_api_pagination_links'

module MyHealth
  module V1
    class FoldersController < SMController
      include MyHealth::JsonApiPaginationLinks

      def index
        resource = client.get_folders(@current_user.uuid, use_cache?, requires_oh_messages)
        links = pagination_links(resource)
        resource = resource.paginate(**pagination_params)

        options = { meta: resource.metadata, links: }
        render json: MyHealth::V1::FolderSerializer.new(resource.data, options)
      end

      def show
        id = params[:id].try(:to_i)
        resource = client.get_folder(id, requires_oh_messages)
        raise Common::Exceptions::RecordNotFound, id if resource.blank?

        render json: MyHealth::V1::FolderSerializer.new(resource, { meta: resource.metadata })
      end

      def create
        folder = Folder.new(create_folder_params)
        raise Common::Exceptions::ValidationErrors, folder unless folder.valid?

        resource = client.post_create_folder(folder.name)
        render json: MyHealth::V1::FolderSerializer.new(resource, { meta: resource.metadata }), status: :created
      end

      def update
        folder = Folder.new(create_folder_params)
        raise Common::Exceptions::ValidationErrors, folder unless folder.valid?

        resource = client.post_rename_folder(params[:id], folder.name)
        render json: MyHealth::V1::FolderSerializer.new(resource, { meta: resource.metadata }), status: :created
      end

      def destroy
        client.delete_folder(params[:id])
        head :no_content
      end

      def search
        message_search = MessageSearch.new(search_params)
        resource = client.post_search_folder(params[:id], params[:page], params[:per_page], message_search,
                                             requires_oh_messages)

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

      def requires_oh_messages
        params[:requires_oh_messages].try(:to_s)
      end
    end
  end
end
