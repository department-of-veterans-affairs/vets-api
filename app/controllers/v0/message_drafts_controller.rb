# frozen_string_literal: true
module V0
  class MessageDraftsController < SMController
    def create
      params = draft_create_params
      draft = MessageDraft.new(params)
      raise Common::Exceptions::ValidationErrors, draft unless draft.valid?
      response = client.post_create_message_draft(params)

      render json: response,
             serializer: MessageSerializer,
             meta:  {}
    end

    def update
      params = draft_update_params
      draft = MessageDraft.new(params)
      raise Common::Exceptions::ValidationErrors, draft unless draft.valid?

      client.post_create_message_draft(params)
      head :no_content
    end

    private

    def draft_create_params
      params.require(:message_draft).permit(:category, :body, :recipient_id, :subject)
    end

    def draft_update_params
      params.require(:message_draft).permit(:id, :category, :body, :recipient_id, :subject)
    end
  end
end
