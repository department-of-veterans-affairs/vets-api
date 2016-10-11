# frozen_string_literal: true
module V0
  class FoldersController < SMController
    SORT_FIELDS   = %w(name).freeze
    SORT_TYPES    = (SORT_FIELDS + SORT_FIELDS.map { |field| "-#{field}" }).freeze
    DEFAULT_SORT  = 'name'

    def index
      resource = client.get_folders
      resource = resource.sort(params[:sort] || DEFAULT_SORT, allowed: SORT_TYPES)
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
      folder = Folder.new(create_folder_params)
      raise Common::Exceptions::ValidationErrors, folder unless folder.valid?

      resource = client.post_create_folder(folder.name)

      render json: resource,
             serializer: FolderSerializer,
             meta: resource.metadata,
             status: :created
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
