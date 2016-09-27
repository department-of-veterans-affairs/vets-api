# frozen_string_literal: true
module V0
  class MessageDraftsController < SMController
    def create
      draft = MessageDraft.new(draft_params)
      raise Common::Exceptions::ValidationErrors, draft unless draft.valid?
      response = client.post_create_message_draft(draft_params)

      render json: response,
             serializer: MessageSerializer,
             meta:  {},
             status: :created
    end

    def update
      draft = MessageDraft.new(draft_params)
      raise Common::Exceptions::ValidationErrors, draft unless draft.valid?

      client.post_create_message_draft(draft_params.merge(id: params[:id]))
      head :no_content
    end

    private

    def draft_params
      @draft_params ||= params.require(:message_draft).permit(:category, :body, :recipient_id, :subject)
    end
  end
end
