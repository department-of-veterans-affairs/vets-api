# frozen_string_literal: true

module Mobile
  module V0
    class ThreadsController < MessagingController
      def index
        resource = client.get_folder_threads(
          params[:folder_id].to_s,
          params[:page_size],
          params[:page],
          params[:sort_field],
          params[:sort_order]
        )

        raise Common::Exceptions::RecordNotFound, params[:folder_id] if resource.blank?

        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: MyHealth::V1::ThreadsSerializer,
               meta: resource.metadata
      end
    end
  end
end
