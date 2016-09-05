# frozen_string_literal: true
module V0
  class MessagesController < HealthcareMessagingController
    def index
      id = params[:id].try(:to_i)
      messages = client.get_folder_messages(id)

      raise VA::API::Common::Exceptions::RecordNotFound, id unless messages.present?

      render json: messages.data,
             serializer: CollectionSerializer,
             each_serializer: MessagesSerializer,
             meta: messages.metadata
    end
  end
end
