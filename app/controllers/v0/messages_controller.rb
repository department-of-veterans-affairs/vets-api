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
      params = message_params
      Rails.logger.error "@@@@@@@@@@@ #{params.inspect}"
      response = client.post_create_message(subject: params[:subject], body: params[:body], id: params[:id],
                                            recipient_id: params[:recipient_id], category: params[:category])
      render json: response,
             serializer: MessageSerializer,
             meta:  {}
    end

    # TODO: uncomment once clarification received on deleting draft messages
    # def destroy
    #   message_id = message_params[:id].try(:to_i)
    #   response = client.delete_message(message_id)
    #
    #   raise VA::API::Common::Exceptions::RecordNotFound, message_id unless response.present?
    #
    #   render json: response
    # end

    # TODO: rework draft
    # def draft
    #   params = message_params
    #   response = client.post_create_message_draft(subject: params[:subject], body: params[:body], id: params[:id],
    #                                               recipient_id: params[:recipient_id], category: params[:category])
    #   render json: response,
    #          serializer: MessageSerializer,
    #          meta:  {}
    # end

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
      params.permit(:id, :category, :body, :recipient_id, :subject, :format)
    end
  end
end
