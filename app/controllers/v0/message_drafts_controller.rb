# frozen_string_literal: true
module V0
  class MessageDraftsController < SMController
    def create
      response = client.post_create_message_draft(draft_create_params)
      # Should we accept default Gem error handling when creating a message with invalid parameter set, or
      # create a VA common exception?

      render json: response,
             serializer: MessageSerializer,
             meta:  {}
    end

    def update
      params = draft_params
      raise VA::API::Common::Exceptions::ParameterMissing, :id unless params[:id].present?

      response = client.post_create_message_draft(draft_update_params)

      render json: response,
             serializer: MessageSerializer,
             meta:  {}
    end

    private

    def draft_create_params
      # Call to MHV message create fails if unknown field present, and does not accept recipient_id. This
      # functionality will be moved into 'gem' once gem is moved to vets-api.
      params.require(:message_draft).permit(:category, :body, :recipient_id, :subject).transform_keys do |k|
        k.camelize(:lower)
      end
    end

    def draft_update_params
      # Call to MHV message create fails if unknown field present, and does not accept recipient_id. This
      # functionality will be moved into 'gem' once gem is moved to vets-api.
      params.require(:message_draft).permit(:id, :category, :body, :recipient_id, :subject).transform_keys do |k|
        k.camelize(:lower)
      end
    end
  end
end
