# frozen_string_literal: true
module V0
  class AttachmentsController < SMController
    CONTENT_DISPOSITION = 'attachment; filename='
    def show
      client_response = client.get_attachment(params[:message_id], params[:id])
      raise Common::Exceptions::RecordNotFound, params[:id] unless client_response.present?

      content_disposition = client_response.response_headers['content-disposition']
      filename = content_disposition.gsub(CONTENT_DISPOSITION, '')
      send_data(client_response[:body], filename: filename)
    end
  end
end
