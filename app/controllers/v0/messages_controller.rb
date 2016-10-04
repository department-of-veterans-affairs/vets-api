# frozen_string_literal: true
module V0
  class MessagesController < SMController
    def index
      resource = client.get_folder_messages(params[:folder_id].to_s)
      raise Common::Exceptions::RecordNotFound, params[:folder_id] unless resource.present?
      resource = resource.paginate(pagination_params)

      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: MessageSerializer,
             meta: resource.metadata
    end

    def show
      message_id = params[:id].try(:to_i)
      response = client.get_message(message_id)

      raise Common::Exceptions::RecordNotFound, message_id unless response.present?

      render json: response,
             include: :attachments,
             serializer: MessageSerializer,
             meta: response.metadata
    end

    def create
      message = Message.new(message_params)
      raise Common::Exceptions::ValidationErrors, message unless message.valid?
      response =
        if request.content_type == 'multipart/form-data'
          client.post_create_message_with_attachment(message_params.merge(file: params[:file]))
        else
          client.post_create_message(message_params)
        end

      render json: response,
             serializer: MessageSerializer,
             meta:  {}
    end

    def destroy
      client.delete_message(params[:id])
      head :no_content
    end

    def thread
      message_id = params[:id].try(:to_i)
      resource = client.get_message_history(message_id)
      raise Common::Exceptions::RecordNotFound, message_id unless resource.present?
      resource = resource.paginate(pagination_params)

      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: MessageSerializer,
             meta: resource.metadata
    end

    def reply
      message = Message.new(message_params)

      if message.body.blank?
        message.errors.add(:body, "can't be blank")
        raise Common::Exceptions::ValidationErrors, message
      end

      resource = client.post_create_message_reply(params[:id], message_params)

      render json: resource,
             serializer: MessageSerializer,
             status: :created
    end

    def categories
      resource = client.get_categories

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
      @message_params ||= params.require(:message).permit(:category, :body, :recipient_id, :subject)
    end
  end
end
