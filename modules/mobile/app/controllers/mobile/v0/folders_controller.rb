# frozen_string_literal: true

module Mobile
  module V0
    class FoldersController < MessagingController
      def index
        resource = client.get_folders(@current_user.uuid, use_cache?)
        links = pagination_links(resource)
        resource = resource.paginate(**pagination_params)
        options = { meta: resource.metadata, links: }
        render json: Mobile::V0::FolderSerializer.new(resource.data, options)
      end

      def show
        id = params[:id].try(:to_i)
        resource = client.get_folder(id)
        raise Common::Exceptions::RecordNotFound, id if resource.blank?

        options = { meta: resource.metadata }
        render json: Mobile::V0::FolderSerializer.new(resource, options)
      end

      def create
        folder = Folder.new(create_folder_params)
        raise Common::Exceptions::ValidationErrors, folder unless folder.valid?

        resource = client.post_create_folder(folder.name)

        options = { meta: resource.metadata }
        render json: Mobile::V0::FolderSerializer.new(resource, options), status: :created
      end

      def destroy
        client.delete_folder(params[:id])
        head :no_content
      end

      private

      def create_folder_params
        params.require(:folder).permit(:name)
      end
    end
  end
end
