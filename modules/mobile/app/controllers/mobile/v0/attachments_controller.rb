# frozen_string_literal: true

module Mobile
  module V0
    class AttachmentsController < MessagingController
      def show
        response = client.get_attachment(params[:message_id], params[:id])
        raise Common::Exceptions::RecordNotFound, params[:id] if response.blank?

        send_data(response[:body], filename: response[:filename])
      end
    end
  end
end
