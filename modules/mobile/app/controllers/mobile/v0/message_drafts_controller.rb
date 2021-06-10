# frozen_string_literal: true

require_dependency 'mobile/messaging_controller'

module Mobile
  module V0
    class MessageDraftsController < MessagingController
      def create
        draft_response = client.post_create_message_draft(draft_params.to_h)
        render json: draft_response,
               serializer: Mobile::V0::MessagesSerializer,
               status: :created
      end

      def update
        create_draft_params = { message_draft: draft_params.to_h, id: params[:id] }
        client.post_create_message_draft(create_draft_params)
        head :no_content
      end

      def create_reply_draft
        draft_response = client.post_create_message_draft_reply(params[:reply_id], reply_draft_params.to_h)
        render json: draft_response,
               serializer: Mobile::V0::MessagesSerializer,
               status: :created
      end

      def update_reply_draft
        create_reply_draft_params = { message_draft: reply_draft_params.to_h, id: params[:draft_id] }
        client.post_create_message_draft_reply(
          params[:reply_id], create_reply_draft_params
        )
        head :no_content
      end

      private

      def draft_params
        @draft_params ||= begin
          params[:message_draft] = JSON.parse(params[:message_draft]) if params[:message_draft].is_a?(String)
          params.require(:message_draft).permit(:category, :body, :recipient_id, :subject)
        end
      end

      def reply_draft_params
        @reply_draft_params ||= begin
          # TODO: fix redundant JSON.parse maybe
          params[:message_draft] = JSON.parse(params[:message_draft]) if params[:message_draft].is_a?(String)
          params.require(:message_draft).permit(:body)
        end
      end
    end
  end
end
