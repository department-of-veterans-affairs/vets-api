# frozen_string_literal: true

module V0
  class MessagesController < SMController
    include Filterable

    def index
      resource = client.get_folder_messages(@current_user.uuid, params[:folder_id].to_s, use_cache?)
      raise Common::Exceptions::RecordNotFound, params[:folder_id] if resource.blank?

      resource = resource.find_by(filter_params) if params[:filter].present?
      resource = resource.order(params[:sort])  if params[:sort].present?
      resource = resource.paginate(**pagination_params)

      links = pagination_links(resource)
      options = { meta: resource.metadata, links: }
      render json: MessagesSerializer.new(resource.records, options)
    end

    def show
      message_id = params[:id].try(:to_i)
      response = client.get_message(message_id)

      raise Common::Exceptions::RecordNotFound, message_id if response.blank?

      options = {
        meta: response.metadata
      }
      render json: MessageSerializer.new(response, options)
    end

    def create
      message = Message.new(message_params.merge(upload_params))
      raise Common::Exceptions::ValidationErrors, message unless message.valid?

      message_params[:id] = message_params.delete(:draft_id) if message_params[:draft_id].present?
      create_message_params = { message: message_params }.merge(upload_params)

      client_response = if message.uploads.present?
                          client.post_create_message_with_attachment(create_message_params)
                        else
                          client.post_create_message(message_params)
                        end
      options = { meta: {} }
      options[:include] = [:attachments] if client_response.attachment
      render json: MessageSerializer.new(client_response, options)
    end

    def destroy
      client.delete_message(params[:id])
      head :no_content
    end

    def thread
      message_id = params[:id].try(:to_i)
      resource = client.get_message_history(message_id)
      raise Common::Exceptions::RecordNotFound, message_id if resource.blank?

      options = { meta: resource.metadata }
      render json: MessagesSerializer.new(resource.records, options)
    end

    def reply
      message = Message.new(message_params.merge(upload_params)).as_reply
      raise Common::Exceptions::ValidationErrors, message unless message.valid?

      message_params[:id] = message_params.delete(:draft_id) if message_params[:draft_id].present?
      create_message_params = { message: message_params }.merge(upload_params)

      client_response = if message.uploads.present?
                          client.post_create_message_reply_with_attachment(params[:id], create_message_params)
                        else
                          client.post_create_message_reply(params[:id], message_params)
                        end
      options = { meta: {} }
      options[:include] = [:attachments] if client_response.attachment
      render json: MessageSerializer.new(client_response, options), status: :created
    end

    def categories
      render json: CategorySerializer.new(client.get_categories)
    end

    def move
      folder_id = params.require(:folder_id)
      client.post_move_message(params[:id], folder_id)
      head :no_content
    end

    private

    def message_params
      @message_params ||= params.require(:message).permit(:draft_id, :category, :body, :recipient_id, :subject)
    end

    def upload_params
      @upload_params ||= { uploads: params[:uploads] }
    end
  end
end
