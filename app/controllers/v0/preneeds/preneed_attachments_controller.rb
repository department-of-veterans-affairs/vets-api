# frozen_string_literal: true
module V0
  module Preneeds
    class PreneedAttachmentsController < PreneedsController
      def create
        preneed_attachment = ::Preneeds::PreneedAttachment.new
        preneed_attachment.set_file_data!(params[:preneed_attachment][:file_data])
        preneed_attachment.save!
        render(json: preneed_attachment)
      end
    end
  end
end
