# frozen_string_literal: true
module V0
  class MessagesController < HealthcareMessagingController
    def index
      id = params[:id].try(:to_i)
      folder_id = params[:folder_id].try(:to_i)
      messages = client.get_folder_messages(folder_id, 1, 100)

      raise VA::API::Common::Exceptions::RecordNotFound, id unless messages.present?

      render json: messages.data,
             serializer: CollectionSerializer,
             each_serializer: MessageSerializer,
             meta: messages.metadata
    end
  end
end
