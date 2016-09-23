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
      message = message_params
      raise Common::Exceptions::ValidationErrors, message unless message.valid?
      response = client.post_create_message(message)

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

    private

    def message_params
      # Call to MHV message create fails if unknown field present, and does not accept recipient_id. This
      # functionality will be moved into 'gem' once gem is moved to vets-api.
      params.require(:message).permit(:id, :category, :body, :recipient_id, :subject).transform_keys do |k|
        k.camelize(:lower)
      end
    end
  end
end
