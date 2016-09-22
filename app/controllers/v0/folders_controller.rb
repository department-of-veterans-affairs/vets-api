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
      raise VA::API::Common::Exceptions::RecordNotFound, id unless resource.present?

      render json: resource,
             serializer: FolderSerializer,
             meta: resource.metadata
    end

    def create
      
    end
  end
end
