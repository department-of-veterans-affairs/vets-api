# frozen_string_literal: true
module V0
  class MessagesController < HealthcareMessagingController
    def index
      pp = pagination_params
      # TODO: convert to a hash arg once sm gem is moved over.
      response = client.get_folder_messages(pp[:folder_id], pp[:page], pp[:per_page], pp[:all])

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

      render json: response,
             serializer: MessageSerializer,
             meta: response.metadata
    end

    def create
      response = client.post_create_message(message_params)
      # Should we accept default Gem error handling when creating a message with invalid parameter set, or
      # create a VA common exception?

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
      response = client.get_message_history(message_id)

      raise VA::API::Common::Exceptions::RecordNotFound, message_id unless response.present?

      render json: response.data,
             serializer: CollectionSerializer,
             each_serializer: MessageSerializer,
             meta: {}
    end

    def categories
      response = client.get_categories

      raise VA::API::Common::Exceptions::InternalServerError unless response.present?

      render json: response,
             serializer: CategorySerializer,
             meta: {}
    end

    private

    def message_params
      # Call to MHV message create fails if unknown field present, and does not accept recipient_id. This
      # functionality will be moved into 'gem' once gem is moved to vets-api.
      params.permit(:id, :category, :body, :recipient_id, :subject).transform_keys do |k|
        k.camelize(:lower)
      end
    end
  end
end
