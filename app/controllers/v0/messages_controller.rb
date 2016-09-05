# frozen_string_literal: true
module V0
  class MessagesController < HealthcareMessagingController
    def index
      folder_id = params[:folder_id].try(:to_i)
      response = client.get_folder_messages(folder_id, 1, 100)

      raise VA::API::Common::Exceptions::RecordNotFound, folder_id unless response.present?

      render json: response.data,
             serializer: CollectionSerializer,
             each_serializer: MessageSerializer,
             meta: response.metadata
    end

    def show
      message_id = params[:id].try(:to_i)
      response = client.get_message(message_id)

      raise VA::API::Common::Exceptions::RecordNotFound, message_id unless response.present?

      render json: response.data[0],
             serializer: MessageSerializer,
             meta: response.data[0].metadata
    end
  end
end
