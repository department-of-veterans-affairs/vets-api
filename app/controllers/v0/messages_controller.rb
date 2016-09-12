# frozen_string_literal: true
module V0
  class MessagesController < HealthcareMessagingController
    def index
      pagination = pagination_params
      response = get_messages(pagination[:folder_id], pagination)

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
    def destroy
      message_id = message_params[:id].try(:to_i)
      response = client.delete_message(message_id)

      raise VA::API::Common::Exceptions::RecordNotFound, message_id unless response.present?

      render json: response
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
      response = client.get_message_history(message_id)

      raise VA::API::Common::Exceptions::RecordNotFound, message_id unless response.present?

      render json: response.data,
             serializer: CollectionSerializer,
             each_serializer: MessageSerializer,
             meta: {}
    end

    private

    def get_folder(folder_id)
      folders = client.get_folder(folder_id)

      raise VA::API::Common::Exceptions::RecordNotFound, folder_id unless folders.present?
      folders.data.first
    end

    # If page is not supplied, we are bringing back all results in the set. In that case
    # adjust the per_page count to the TBD maximum number of messages allowed per MHV call
    def pagination_params
      folder_id = params[:folder_id].try(:to_i)
      folder = get_folder(folder_id)

      if page = params[:page].try(:to_i)
        pages = page..page
        per_page = [params[:per_page].try(:to_i) || DEFAULT_PER_PAGE, MAXIMUM_PER_PAGE].min
      else
        # We need to test concatenation of multiple message GETS.
        # Use only maximum per page once we can create more messages in a folder.
        per_page = params[:per_page].try(:to_i) ||  MAXIMUM_PER_PAGE
        pages = 1..(folder.count.to_f / per_page).ceil
      end

      { folder_id: folder_id, pages: pages, per_page: per_page, count: folder.count }
    end

    def message_params
      # ActionController::Parameters No Longer Inherits from HashWithIndifferentAccess
      # Gem message api uses keyword arguments and will not work with HashWithIndifferentAccess according
      # to longstanding bug. Allegedly was fixed in Ruby 2.2, but having same issue in Ruby 2.3
      hash = params.permit(:id, :category, :body, :recipient_id, :subject).to_h
      Hash[hash.map{ |k, v| [k.to_sym, v] }]
    end

    # Unwraps data from individual calls to MHV and aggregates the results to a new collection,
    # potentially containing all messages in the folder
    def get_messages(folder_id, pagination)
      data = []
      pagination[:pages].each do |page|
        data.concat(client.get_folder_messages(folder_id, page, pagination[:per_page]).attributes)
      end

      meta = {
        current_page: pagination[:pages].first, per_page: data.length,
        count: pagination[:count], folder_id: folder_id
      }

      VAHealthcareMessaging::Collection.new(VAHealthcareMessaging::Message, data: data, metadata: meta)
    end
  end
end
