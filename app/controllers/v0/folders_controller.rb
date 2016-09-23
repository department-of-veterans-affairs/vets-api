# frozen_string_literal: true
module V0
  class FoldersController < SMController
    def index
      resource = client.get_folders
      resource = resource.paginate(pagination_params)

      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: FolderSerializer,
             meta: resource.metadata
    end

    def show
      id = params[:id].try(:to_i)
      resource = client.get_folder(id)
      raise Common::Exceptions::RecordNotFound, id unless resource.present?

      render json: resource,
             serializer: FolderSerializer,
             meta: resource.metadata
    end

    def create
      resource = Folder.new(create_folder_params)
      if resource.valid?
        resource = client.post_create_folder(resource.name)

        render json: resource,
               serializer: FolderSerializer,
               meta: resource.metadata,
               status: :created
      else
        raise Common::Exceptions::ValidationErrors, resource
      end
    end

    private

    def create_folder_params
      params.require(:folder).permit(:name)
    end
  end
end
