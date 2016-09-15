# frozen_string_literal: true
module V0
  class FoldersController < HealthcareMessagingController
    def index
      folders = client.get_folders
      render json: folders.data,
             serializer: CollectionSerializer,
             each_serializer: FolderSerializer,
             meta: folders.metadata
    end

    def show
      id = params[:id].try(:to_i)
      resource = client.get_folder(id)
      raise VA::API::Common::Exceptions::RecordNotFound, id unless resource.present?

      render json: resource,
             serializer: FolderSerializer,
             meta: resource.metadata
    end
  end
end
