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
      # ActionController::Parameters No Longer Inherits from HashWithIndifferentAccess
      # Gem message api uses keyword arguments and will not work with HashWithIndifferentAccess according
      # to longstanding bug. Allegedly was fixed in Ruby 2.2, but having same issue in Ruby 2.3
      hash = params.permit(:id, :category, :body, :recipient_id, :subject).to_h
      Hash[hash.map{ |k, v| [k.to_sym, v] }]
    end
  end
end
