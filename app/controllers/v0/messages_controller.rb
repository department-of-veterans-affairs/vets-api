# frozen_string_literal: true
module V0
  class MessagesController < SMController
    include Filterable

    SORT_FIELDS   = %w(subject sent_date sender_name recipient_name).freeze
    SORT_TYPES    = (SORT_FIELDS + SORT_FIELDS.map { |field| "-#{field}" }).freeze
    DEFAULT_SORT  = '-sent_date'

    PERMITTED_FILTERS = {
      'subject' => %w(eq not_eq),
      'sender_name' => %w(eq not_eq),
      'recipient_name' => %w(eq not_eq),
      'sent_date' => %w(eq lteq gteq)
    }.freeze

    def index
      resource = client.get_folder_messages(params[:folder_id].to_s)
      raise Common::Exceptions::RecordNotFound, params[:folder_id] unless resource.present?
      resource = filter? ? resource.find_by(params[:filter]) : resource
      resource = resource.sort(params[:sort] || DEFAULT_SORT, allowed: SORT_TYPES)
      resource = resource.paginate(pagination_params)

      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: MessagesSerializer,
             meta: resource.metadata
    end

    def show
      message_id = params[:id].try(:to_i)
      response = client.get_message(message_id)

      raise Common::Exceptions::RecordNotFound, message_id unless response.present?

      render json: response,
             serializer: MessageSerializer,
             include: 'attachments',
             meta: response.metadata
    end

    def create
      message = Message.new(create_message_params)
      raise Common::Exceptions::ValidationErrors, message unless message.valid?

      if message.uploads.present?
        client_response = client.post_create_message_with_attachment(create_message_params)
      else
        client_response = client.post_create_message(message_params)
      end

      render json: client_response,
             serializer: MessageSerializer,
             include: 'attachments',
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
             each_serializer: MessagesSerializer,
             meta: resource.metadata
    end

    def reply
      message = Message.new(create_message_params).as_reply
      raise Common::Exceptions::ValidationErrors, message unless message.valid?

      if message.uploads.present?
        client_response = client.post_create_message_reply_with_attachment(params[:id], create_message_params)
      else
        client_response = client.post_create_message_reply(params[:id], message_params)
      end

      render json: client_response,
             serializer: MessageSerializer,
             include: 'attachments',
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

    def create_message_params
      @create_message_params ||= message_params.merge(uploads: params[:uploads])
    end

    def filter?
      can_filter?(Message, PERMITTED_FILTERS)
    end
  end
end
