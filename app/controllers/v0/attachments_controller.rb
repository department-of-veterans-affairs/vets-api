# frozen_string_literal: true
module V0
  class AttachmentsController < SMController
    def show
      response = client.get_attachment(params[:message_id], params[:id])
      raise Common::Exceptions::RecordNotFound, params[:id] unless response.present?

      send_data(response[:body], filename: response[:filename])
    end
  end
end
