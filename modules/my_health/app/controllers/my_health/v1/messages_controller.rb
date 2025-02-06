# frozen_string_literal: true

module MyHealth
  module V1
    class MessagesController < SMController
      include Filterable

      def index
        resource = client.get_folder_messages(@current_user.uuid, params[:folder_id].to_s, use_cache?)
        raise Common::Exceptions::RecordNotFound, params[:folder_id] if resource.blank?

        resource = resource.find_by(filter_params) if params[:filter].present?
        resource = resource.sort(params[:sort])
        resource = resource.paginate(**pagination_params) if pagination_params[:per_page] != '-1'

        links = pagination_links(resource)
        options = { meta: resource.metadata, links: }
        render json: MessagesSerializer.new(resource.data, options)
      end

      def show
        message_id = params[:id].try(:to_i)
        response = client.get_message(message_id)

        raise Common::Exceptions::RecordNotFound, message_id if response.blank?

        options = { meta: response.metadata }
        render json: MessageSerializer.new(response, options)
      end

      def create
        message = Message.new(message_params.merge(upload_params))
        raise Common::Exceptions::ValidationErrors, message unless message.valid?

        message_params_h = message_params.to_h
        message_params_h[:id] = message_params_h.delete(:draft_id) if message_params_h[:draft_id].present?
        create_message_params = { message: message_params_h }.merge(upload_params)

        client_response = if message.uploads.present?
                            client.post_create_message_with_attachment(create_message_params)
                          else
                            client.post_create_message(message_params_h)
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
        resource = if params[:full_body] == 'true'
                     # returns full body of message including attachments attributes
                     client.get_full_messages_for_thread(message_id, params[:requires_oh_messages].to_s)
                   else
                     client.get_messages_for_thread(message_id, params[:requires_oh_messages].to_s)
                   end
        raise Common::Exceptions::RecordNotFound, message_id if resource.blank?

        options = { meta: resource.metadata, is_collection: true }
        render json: MessageDetailsSerializer.new(resource, options)
      end

      def reply
        message = Message.new(message_params.merge(upload_params)).as_reply
        raise Common::Exceptions::ValidationErrors, message unless message.valid?

        message_params_h = message_params.to_h
        message_params_h[:id] = message_params_h.delete(:draft_id) if message_params_h[:draft_id].present?
        create_message_params = { message: message_params_h }.merge(upload_params)

        client_response = if message.uploads.present?
                            client.post_create_message_reply_with_attachment(params[:id], create_message_params)
                          else
                            client.post_create_message_reply(params[:id], message_params_h)
                          end

        options = { meta: {} }
        options[:include] = [:attachments] if client_response.attachment
        render json: MessageSerializer.new(client_response, options), status: :created
      end

      def categories
        resource = client.get_categories

        render json: CategorySerializer.new(resource)
      end

      def signature
        resource = client.get_signature
        if resource[:data].nil?
          resource[:data] =
            { signature_name: nil, include_signature: false, signature_title: nil }
        end
        # see MessageSignatureSerializer for more information
        render json: resource
      end

      def move
        folder_id = params.require(:folder_id)
        client.post_move_message(params[:id], folder_id)
        head :no_content
      end

      private

      def message_params
        @message_params ||= begin
          params[:message] = JSON.parse(params[:message]) if params[:message].is_a?(String)
          params.require(:message).permit(:draft_id, :category, :body, :recipient_id, :subject)
        end
      end

      def upload_params
        @upload_params ||= { uploads: params[:uploads] }
      end
    end
  end
end
