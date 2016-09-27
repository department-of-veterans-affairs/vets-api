# frozen_string_literal: true
module V0
  class MessagesController < SMController
    def index
      resource = client.get_folder_messages(params[:folder_id].to_s)
      raise VA::API::Common::Exceptions::RecordNotFound, params[:folder_id] unless resource.present?
      resource = resource.paginate(pagination_params)

      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: MessageSerializer,
             meta: resource.metadata
    end

    def show
      message_id = params[:id].try(:to_i)
      response = client.get_message(message_id)

      raise VA::API::Common::Exceptions::RecordNotFound, message_id unless response.present?

      render json: response,
             serializer: MessageSerializer,
             meta: response.metadata
    end

    def create
      message = Message.new(message_params)
      raise Common::Exceptions::ValidationErrors, message unless message.valid?

      response = client.post_create_message(message_params)

      render json: response,
             serializer: MessageSerializer,
             meta:  {}
    end

    def destroy
      client.delete_message(params[:id])
      head :no_content
    end

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
      resource = client.get_message_history(message_id)
      raise VA::API::Common::Exceptions::RecordNotFound, message_id unless resource.present?
      resource = resource.paginate(pagination_params)

      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: MessageSerializer,
             meta: resource.metadata
    end

    def categories
      resource = client.get_categories
      raise VA::API::Common::Exceptions::InternalServerError unless response.present?

      render json: resource,
             serializer: CategorySerializer
    end

    def move
      folder_id = params.require(:folder_id)
      client.post_move_message(params[:id], folder_id)
      head :no_content
    end

    private

    def message_params
      params.require(:message).permit(:id, :category, :body, :recipient_id, :subject)
    end
  end
end
