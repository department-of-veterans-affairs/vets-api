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
      response = client.post_create_message(symbolized_hash(message_params.to_h))
      render json: response,
             serializer: MessageSerializer,
             meta:  {}
    end

    def draft
      response = client.post_create_message_draft(symbolized_hash(message_params.to_h))
      render json: response,
             serializer: MessageSerializer,
             meta:  {}
    end

    def thread
      message_id = params[:id].try(:to_i)
      response = client.get_message_history(message_id)

      raise VA::API::Common::Exceptions::RecordNotFound, message_id unless response.present?

      render json: response.data,
             serializer: CollectionSerializer,
             each_serializer: MessageSerializer,
             meta: {}
    end

    private

    def message_params
      params.permit(:id, :subject, :category, :recipient_id, :body, :format).except(:format)
    end

    def symbolized_hash(h)
      h.each_with_object({}) do |v, m|
        m[v[0].to_sym] = v[1]
        m
      end
    end
  end
end
