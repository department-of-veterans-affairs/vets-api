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

    def create
      subject = params[:subject]
      category = params[:category]
      recipient_id = params[:recipient_id]
      body = params[:body]

      response = client.post_create_message(subject: subject,
                                            category: category, recipient_id: recipient_id, body: body)

      render json: response,
             serializer: MessageSerializer,
             meta:  {}
    end

    def draft
      subject = params[:subject]
      category = params[:category]
      recipient_id = params[:recipient_id]
      body = params[:body]
      id = params[:id]

      response = client.post_create_message_draft(id: id, subject: subject,
                                                  category: category, recipient_id: recipient_id, body: body)

      render json: response,
             serializer: MessageSerializer,
             meta:  {}
    end
  end
end
