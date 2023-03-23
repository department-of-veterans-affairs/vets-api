# frozen_string_literal: true

require_dependency 'mobile/messaging_controller'

module Mobile
  module V0
    class MessagesController < MessagingController
      include Filterable

      def index
        resource = client.get_folder_messages(@current_user.uuid, params[:folder_id].to_s, use_cache?)
        raise Common::Exceptions::RecordNotFound, params[:folder_id] if resource.blank?

        resource = params[:filter].present? ? resource.find_by(filter_params) : resource
        resource = resource.sort(params[:sort])
        resource = resource.paginate(**pagination_params)

        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: Mobile::V0::MessagesSerializer,
               meta: resource.metadata
      end

      def show
        message_id = params[:id].try(:to_i)
        response = client.get_message(message_id)

        raise Common::Exceptions::RecordNotFound, message_id if response.blank?

        render json: response,
               serializer: Mobile::V0::MessageSerializer,
               include: {
                 attachments: { serializer: Mobile::V0::AttachmentSerializer }
               },
               meta: response.metadata
      end

      def create
        message = Message.new(message_params.merge(upload_params))
        raise Common::Exceptions::ValidationErrors, message unless message.valid?

        message_params[:id] = message_params.delete(:draft_id) if message_params[:draft_id].present?
        create_message_params = { message: message_params.to_h }.merge(upload_params)

        client_response = if message.uploads.present?
                            client.post_create_message_with_attachment(create_message_params)
                          else
                            client.post_create_message(message_params.to_h)
                          end

        render json: client_response,
               serializer: Mobile::V0::MessageSerializer,
               include: 'attachments',
               meta: {}
      end

      def destroy
        client.delete_message(params[:id])
        head :no_content
      end

      def thread
        message_id = params[:id].try(:to_i)
        resource = client.get_message_history(message_id)
        raise Common::Exceptions::RecordNotFound, message_id if resource.blank?

        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: Mobile::V0::MessagesSerializer,
               meta: resource.metadata
      end

      def reply
        message = Message.new(message_params.merge(upload_params)).as_reply
        raise Common::Exceptions::ValidationErrors, message unless message.valid?

        message_params[:id] = message_params.delete(:draft_id) if message_params[:draft_id].present?
        create_message_params = { message: message_params.to_h }.merge(upload_params)

        client_response = if message.uploads.present?
                            client.post_create_message_reply_with_attachment(params[:id], create_message_params)
                          else
                            client.post_create_message_reply(params[:id], message_params.to_h)
                          end

        render json: client_response,
               serializer: Mobile::V0::MessageSerializer,
               include: 'attachments',
               status: :created
      end

      def categories
        resource = client.get_categories

        render json: resource,
               serializer: Mobile::V0::CategorySerializer
      end

      def move
        folder_id = params.require(:folder_id)
        client.post_move_message(params[:id], folder_id)
        head :no_content
      end

      def signature
        result = client.get_signature[:data]
        Rails.logger.info('Mobile Get Message Signature Result', result:)
        result = { signature_name: nil, include_signature: false, signature_title: nil } if result.nil?
        render json: Mobile::V0::MessageSignatureSerializer.new(@current_user.uuid, result).to_json
      end

      private

      # When we get message parameters as part of a multipart payload (i.e. with attachments),
      # ActionController::Parameters leaves the message part as a string so we have to turn it into
      # an object
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
