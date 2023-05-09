# frozen_string_literal: true

module Mobile
  module V0
    class MessageDraftsController < MessagingController
      def create
        draft_response = client.post_create_message_draft(draft_params.to_h)
        render json: draft_response,
               serializer: Mobile::V0::MessageSerializer,
               status: :created,
               meta: {}
      end

      def update
        client.post_create_message_draft(draft_params.merge(id: params[:id]).to_h)
        head :no_content
      end

      def create_reply_draft
        draft_response = client.post_create_message_draft_reply(params[:reply_id], reply_draft_params.to_h)
        render json: draft_response,
               serializer: Mobile::V0::MessageSerializer,
               status: :created,
               meta: {}
      end

      def update_reply_draft
        client.post_create_message_draft_reply(
          params[:reply_id], reply_draft_params.merge(id: params[:draft_id]).to_h
        )
        head :no_content
      end

      private

      def draft_params
        @draft_params ||= params.require(:message_draft).permit(:category, :body, :recipient_id, :subject)
      end

      def reply_draft_params
        @reply_draft_params ||= params.require(:message_draft).permit(:body)
      end
    end
  end
end
